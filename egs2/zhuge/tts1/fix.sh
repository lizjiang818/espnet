# 创建修复目录
mkdir -p data_fix

# 修复 train 数据
cd data/train

# 提取两个文件共同的 utterance IDs
awk '{print $1}' text | sort > ../text_utts
awk '{print $1}' utt2spk | sort > ../utt2spk_utts

# 找出共同的 utterance IDs
comm -12 ../text_utts ../utt2spk_utts > ../common_utts

# 基于共同的 utterance IDs 重新创建文件
awk 'NR==FNR{utts[$1]=1; next} $1 in utts' ../common_utts text > text.new
awk 'NR==FNR{utts[$1]=1; next} $1 in utts' ../common_utts utt2spk > utt2spk.new
awk 'NR==FNR{utts[$1]=1; next} $1 in utts' ../common_utts wav.scp > wav.scp.new

# 备份原文件并替换
mv text text.bak
mv utt2spk utt2spk.bak
mv wav.scp wav.scp.bak

mv text.new text
mv utt2spk.new utt2spk
mv wav.scp.new wav.scp

# 重新生成 spk2utt
utils/utt2spk_to_spk2utt.pl utt2spk > spk2utt

cd ../..
