#!/usr/bin/env bash
# =============================
# ZhugeLiang Chinese VITS Trainer
# =============================
set -e
set -u
set -o pipefail

# -----------------------------
# 基本参数（采样率、STFT）
# -----------------------------
fs=22050
n_fft=1024
n_shift=256

# -----------------------------
# 数据集设置
# -----------------------------
# 建议你在 data 目录下准备这3个文件夹：
#   data/train/  -> 训练集
#   data/val/    -> 验证集
#   data/test/   -> 测试集
train_set=train
valid_set=val
test_sets="val test"

# -----------------------------
# 配置文件
# -----------------------------
train_config=conf/tuning/train_vits_chinese.yaml
inference_config=conf/decode.yaml

# -----------------------------
# 中文文本处理设置
# -----------------------------
lang=zh
token_type=phn          # 使用音素（phn），也可以改为 char
cleaner=none   # 对中文语料可用 none_cleaners
g2p=none                # 中文不需要 grapheme-to-phoneme

# -----------------------------
# 音频格式选项
# -----------------------------
opts="--audio_format wav"

# -----------------------------
# 启动TTS主流程
# -----------------------------
./tts.sh \
    --lang "${lang}" \
    --feats_type raw \
    --fs "${fs}" \
    --n_fft "${n_fft}" \
    --n_shift "${n_shift}" \
    --token_type "${token_type}" \
    --cleaner "${cleaner}" \
    --g2p "${g2p}" \
    --train_config "${train_config}" \
    --inference_config "${inference_config}" \
    --train_set "${train_set}" \
    --valid_set "${valid_set}" \
    --test_sets "${test_sets}" \
    --srctexts "data/train.txt" \
    ${opts} "$@"

