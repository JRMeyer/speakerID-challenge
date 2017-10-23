#!/bin/bash

# Joshua Meyer 2017
# <jrmeyer.github.io>

# INPUT  (1): audio_dir/train
#
# OUTPUT (1): audio_dir/audio-noise*.wav
#        (2): audio_dir/utt2spk
#


if [ "$#" -ne 1 ]; then
    echo "$0:Illegal number of parameters"
    exit 1
fi


# this is the dir where training clean wavs are
dir=$1


echo "##############################"
echo "###   BEGIN CORRUPT DATA   ###"
echo "### assuming original data ###"
echo "###     in ${dir}        ###"
echo "##############################"


### CORRUPT FILES ###

# take all wav files, make a copy and corrupt them
# and add new corrupted filename to utt2spk

mkdir $dir/lowpass $dir/noise $dir/amp


for i in $dir/*.wav; do
    i=${i##*/}
    iNoise=${i%.wav}-noise.wav
    uttspk=(${i//-/ })

    sox $dir/$i $dir/lowpass/$iNoise lowpass 3400;
    sox $dir/lowpass/$iNoise -p synth whitenoise vol 0.025 | sox -m $dir/lowpass/$iNoise - $dir/noise/$iNoise
    sox -v 2.5 $dir/noise/$iNoise $dir/amp/$iNoise
    
    cp $dir/amp/$iNoise $dir/$iNoise
    rm $dir/lowpass/* $dir/noise/* $dir/amp/*

    # make new utt2spk right away
    echo "${i%.wav}-noise ${uttspk[0]}" >> $dir/utt2spk.noise
    echo "${i%.wav} ${uttspk[0]}" >> $dir/utt2spk.noise
    
done


# rename new utt2spk and save old one
if [ -f $dir/utt2spk ]; then
    mkdir $dir/.backup/
    echo "utt2spk backup in $dir/.backup/utt2spk"
    cp $dir/utt2spk $dir/.backup/utt2spk
    rm $dir/utt2spk
    cp $dir/utt2spk.noise $dir/utt2spk
    rm $dir/utt2spk.noise
fi


# cleanup 
rm -rf $dir/lowpass $dir/noise $dir/amp


echo ""
echo "### DONE CORRUPTING DATA ###"
num_wavs=`ls $dir -1 | grep ".wav" | wc -l`
echo " Now you have a total of ${num_wavs} training "
echo " utterances in ${dir}.                        "
echo ""
