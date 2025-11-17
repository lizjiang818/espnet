#!/usr/bin/env bash

set -e
set -u
set -o pipefail

log() {
    local fname=${BASH_SOURCE[1]##*/}
    echo -e "$(date '+%Y-%m-%dT%H:%M:%S') (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $*"
}
SECONDS=0

stage=-1
stop_stage=2

log "$0 $*"
. utils/parse_options.sh

if [ $# -ne 0 ]; then
    log "Error: No positional arguments are required."
    exit 2
fi

. ./path.sh || exit 1;
. ./cmd.sh || exit 1;
. ./db.sh || exit 1;

if [ -z "${CUSTOM_CHINESE_TTS}" ]; then
   log "Fill the value of 'CUSTOM_CHINESE_TTS' of db.sh"
   log "Example: CUSTOM_CHINESE_TTS=/content/espnet/dataset"
   exit 1
fi
db_root=${CUSTOM_CHINESE_TTS}

train_set=tr_no_dev
train_dev=dev
recog_set=eval1

if [ ${stage} -le -1 ] && [ ${stop_stage} -ge -1 ]; then
    log "stage -1: Data Download (skip for custom dataset)"
    log "Please ensure your dataset is located at: ${db_root}"
    if [ ! -d "${db_root}" ]; then
        log "Error: Dataset directory does not exist: ${db_root}"
        exit 1
    fi
    if [ ! -d "${db_root}/wavs" ]; then
        log "Error: wavs directory does not exist in: ${db_root}"
        exit 1
    fi
fi

if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    log "stage 0: local/data_prep.sh"

    # check directory existence
    [ ! -e data/train ] && mkdir -p data/train

    # set filenames
    scp=data/train/wav.scp
    utt2spk=data/train/utt2spk
    spk2utt=data/train/spk2utt
    text=data/train/text

    # check file existence
    [ -e ${scp} ] && rm ${scp}
    [ -e ${utt2spk} ] && rm ${utt2spk}
    [ -e ${text} ] && rm ${text}

    # make scp, utt2spk from wavs directory
    log "Processing wav files from ${db_root}/wavs/"
    find ${db_root}/wavs -name "*.wav" -follow | sort | while read -r filename; do
        id="$(basename ${filename} .wav)"
        echo "${id} ${filename}" >> ${scp}
        echo "${id} speaker1" >> ${utt2spk}
    done
    
    if [ ! -s ${scp} ]; then
        log "Error: No wav files found in ${db_root}/wavs/"
        exit 1
    fi
    
    utils/utt2spk_to_spk2utt.pl ${utt2spk} > ${spk2utt}

    # make text from text.txt or metadata.csv
    # Option 1: Use text.txt (format: 0001 文本内容)
    if [ -f "${db_root}/text.txt" ]; then
        log "Using text.txt for text data"
        while IFS= read -r line; do
            # Skip empty lines
            [ -z "$line" ] && continue
            # Format: 0001 文本内容
            echo "$line" >> ${text}
        done < "${db_root}/text.txt"
    # Option 2: Use metadata.csv (format: wav/0001.wav|文本内容)
    elif [ -f "${db_root}/metadata.csv" ]; then
        log "Using metadata.csv for text data"
        while IFS='|' read -r wav_path text_content; do
            # Skip empty lines
            [ -z "$wav_path" ] && continue
            # Extract ID from wav path (e.g., wav/0001.wav -> 0001)
            id=$(basename "$wav_path" .wav)
            # Remove leading/trailing whitespace from text
            text_content=$(echo "$text_content" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -n "$text_content" ] && echo "${id} ${text_content}" >> ${text}
        done < "${db_root}/metadata.csv"
    else
        log "Error: Neither text.txt nor metadata.csv found in ${db_root}"
        exit 1
    fi

    if [ ! -s ${text} ]; then
        log "Error: No text data found or text file is empty"
        exit 1
    fi

    log "Created data files:"
    log "  wav.scp: $(wc -l < ${scp}) entries"
    log "  text: $(wc -l < ${text}) entries"
    log "  utt2spk: $(wc -l < ${utt2spk}) entries"

fi

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    log "stage 1: utils/subset_data_dir.sh"
    # make evaluation and development sets
    # For small datasets, adjust the numbers accordingly
    total_utts=$(wc -l < data/train/wav.scp)
    log "Total utterances: ${total_utts}"
    
    if [ ${total_utts} -lt 20 ]; then
        log "Warning: Dataset is very small (${total_utts} utterances). Using all data for training."
        log "Skipping train/dev/eval split. You may want to add more data."
        # Just copy train to all sets
        utils/copy_data_dir.sh data/train data/${train_set}
        utils/copy_data_dir.sh data/train data/${train_dev}
        utils/copy_data_dir.sh data/train data/${recog_set}
    else
        # Use last 20% for dev/eval, rest for training
        eval_size=$((total_utts / 10))  # 10% for eval
        dev_size=$((total_utts / 10))   # 10% for dev
        train_size=$((total_utts - eval_size - dev_size))
        
        log "Splitting data:"
        log "  Train: ${train_size} utterances"
        log "  Dev: ${dev_size} utterances"
        log "  Eval: ${eval_size} utterances"
        
        utils/subset_data_dir.sh --last data/train $((eval_size + dev_size)) data/deveval
        utils/subset_data_dir.sh --last data/deveval ${eval_size} data/${recog_set}
        utils/subset_data_dir.sh --first data/deveval ${dev_size} data/${train_dev}
        utils/subset_data_dir.sh --first data/train ${train_size} data/${train_set}
    fi
fi

log "Successfully finished. [elapsed=${SECONDS}s]"

