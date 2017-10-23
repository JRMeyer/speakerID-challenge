#!/bin/bash

# Joshua Meyer 2017
# <jrmeyer.github.io>

# INPUT (1) filepath

. ./path.sh



if [ "$#" -ne 1 ]; then
    echo "$0:Illegal number of parameters"
    exit 1
fi

# an absolute path to a 8kHz wave file

abspath=$1

stage=1

#clear up old files and dirs
rm -rf data-test/ feats-test/ audio/ exp/test/


if [ $stage -le 1 ]; then

    echo "#####################################"
    echo "### DATA PREP and FEAT EXTRACTION ###"
    echo "#####################################"

    basename=${abspath##*/}

    # the data prep scripts expect this kind of dir structure:
    # dir/dir/*.wav dir/dir/utt2spk
    mkdir -p audio/test
    ln -s $abspath audio/test/$basename
    echo "${basename%.wav} ${basename%.wav}" >> audio/test/utt2spk
    
    # create data-${data_type} dir
    ./prepare_data.sh audio test
    
    # create feats-${data_type} dir
    ./make_mfcc_and_vad.sh --nj 1 test
    
fi




if [ ! -d "./exp/extractor" ]; then
    echo ""
    echo "# FATAL ERROR: missing ivector extractor"
    echo "# expected extractor to be at exp/extractor/"
    echo "# "
    echo "# if you want to recognize the speaker of"
    echo "# an utterance, you need to extract ivectors"
    echo "# but you seem to be missing the T-matrix."
    echo ""
    exit 1
fi




if [ $stage -le 3 ]; then

    
    echo "#####################################"
    echo "### EXTRACT IVECTORS ${data_type} ###"
    echo "#####################################"
    
    sid/extract_ivectors.sh \
        --cmd './utils/run.pl' \
        --nj 1 \
        exp/extractor \
        data-test \
        exp/ivectors-test
    
fi


if [ ! -d "./exp/ivectors-train/" ]; then
    echo ""
    echo "# FATAL ERROR: missing speaker ivectors"
    echo "# expected ivecs to be at ./exp/ivectors-train/"
    echo "# "
    echo "# if you want to recognize the speaker of"
    echo "# an utterance, you need to compare the utt"
    echo "# ivector against speaker ivecs from some training"
    echo "# dataset. This script expects those ivecs to be"
    echo "# in the dir exp/ivectors-train/"
    exit 1
fi


if [ $stage -le 4 ]; then

    echo "### CREATE TRIALS FILE ###"
    echo "### at ./exp/trials    ###"

    if [ -f ./exp/trials ]; then
        # if trials exists already, back it up
        mkdir ./exp/.backup
        cp ./exp/trials ./exp/.backup/trials
        rm ./exp/trials
    fi
        
    spk_ivecs=./exp/ivectors-train/spk_ivector.scp
    utt_ivecs=./exp/ivectors-test/ivector.scp
    
    trials=./exp/trials

    while read utt; do
        utt=( $utt );
        utt=${utt[0]}
        while read spk; do
            spk=( $spk );
            spk=${spk[0]};
                echo $spk $utt "nontarget" >> $trials;
        done <$spk_ivecs;
    done <$utt_ivecs
fi



if [ ! -f "./exp/ivectors-train/plda" ]; then
    echo ""
    echo "# FATAL ERROR: missing PLDA matrix"
    echo "# expected PLDA to be at ./exp/ivectors-train/plda"
    echo "# "
    echo "# PLDA is used to compare ivectors from an utterance"
    echo "# to speaker ivectors. It is trained offline, and "
    echo "# expected to be ready to use at exp/ivectors-train/plda."
    exit 1
fi



echo "##################"
echo "### SCORE PLDA ###"
echo "##################"

mkdir -p exp/test/plda_scores/log

plda_ivec_dir=exp/ivectors-train
test_ivec_dir=exp/ivectors-test

utils/run.pl exp/test/plda_scores/log/plda_scoring.log \
             ivector-plda-scoring \
             --normalize-length=true \
             --simple-length-normalization=false \
             --num-utts=ark:${plda_ivec_dir}/num_utts.ark \
             "ivector-copy-plda --smoothing=0.0 ${plda_ivec_dir}/plda - |" \
             "ark:${plda_ivec_dir}/spk_ivector.ark" \
             "ark:ivector-normalize-length scp:${test_ivec_dir}/ivector.scp ark:- |" \
             "cat '$trials' | cut -d\  --fields=1,2 |" \
             exp/test/plda_scores/plda_scores \
    || exit 1;


echo " #################### "
echo " ### ASSIGN LABEL ### "
echo " #################### "

echo ""
echo "# v-- BEST SPEAKER ID for UTTERANCE ${abspath} : --v"
./find_best_plda.sh exp/test/plda_scores/plda_scores
echo "# ^-- BEST SPEAKER ID for UTTERANCE ${abspath} : --^ "
echo ""
echo "# HAVE A NICE DAY:)"

