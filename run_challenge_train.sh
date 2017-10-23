#!/bin/bash

# Joshua Meyer 2017
# <jrmeyer.github.io>

# INPUT    audio_dir/
#                    train/
#                          *.wav
#                          utt2spk (optional)
#                    dev/
#                          *.wav
#                          utt2spk (optional)
#
# OUTPUT   data-{train,dev}/
#                           wav.scp
#                           utt2spk
#                           spk2utt
#
#          feats-{train,dev}/
#
#          exp/
#


echo "BEGIN MAIN SCRIPT: `date`"

. ./path.sh

stage=0

if [ "$#" -ne 1 ]; then
    echo "$0:Illegal number of parameters"
    exit 1
fi



audio_dir=$1



# take FLAC files and convert to WAV, with backup in train-org
cp -r $audio_dir/train $audio_dir/train-org

for i in ${audio_dir}/train/*.flac; do
    file=${i##*/}
    base="${file%.*}"
    
    ffmpeg -i $i ${audio_dir}/train/${base}-16k.wav
    sox ${audio_dir}/train/${base}-16k.wav -r 8000 ${audio_dir}/train/${base}.wav

    # remove original FLAC and 16k WAV
    rm -f $i ${audio_dir}/train/${base}-16k.wav
done


if [ $stage -le 0 ]; then

    num_corrupted=0;
    for i in ${audio_dir}/train/*noise*; do
        ((num_corrupted++));
    done

    # the regex itself is counted
    num_corrupted=$num_corrupted-1
    
    if [ $num_corrupted -ge 1 ]; then
        echo ""
        echo "You've got corrupted files already!";
        echo "exactly ${num_corrupted} of them!";
        echo "crashing here, you can either skip"
        echo "this step by setting stage=1"
        echo "or go delete the existing corrupted files"
        echo "located at ${audio_dir}/train/*noise*."
        echo ""
        exit
    fi
    
    ### CORRUPT FILES ###
    # put corrupted files in the specified dir
    # along with a new utt2spk file
    # sox dependency here: sudo apt-get install sox
    corrupt_data.sh $audio_dir/train
    
fi



if [ $stage -le 1 ]; then

    echo "#####################################"
    echo "### DATA PREP and FEAT EXTRACTION ###"
    echo "#####################################"
     
    for data_type in train dev; do

        # create data-${data_type} dir
        # dependencies: utils/utt2spk_to_spk2utt.pl // utils/fix_data_dir.pl
        prepare_data.sh $audio_dir $data_type

        # create feats-${data_type} dir
        # dependencies steps/make_mfcc.sh // sid/compute_vad_decision.sh
        make_mfcc_and_vad.sh $data_type
        
    done   
fi





if [ $stage -le 2 ]; then

    echo "####################################"
    echo "### TRAIN UBM and IVEC EXTRACTOR ###"
    echo "####################################"

    # 400 and 200 EER == 20.79
    # 300 and 150 EER == 20.37
    # 250 and 124 EER == 19.54
    # 200 and 100 EER == 18.58
    # 100 and 50  EER == 19.18
    
    # 200 and 100 with corruption EER == 8.1%!
    # 5 iters for ubm, 5 for ivecs
    #                                    7.5%!
    
    num_components=200
    ivec_dim=100
    
    train_ubm_and_ivec_extractor.sh \
        --num-iters-full-ubm 5 \
        --num-iters-ivec 5 \
        train \
        $num_components \
        $ivec_dim 

fi



if [ $stage -le 3 ]; then

    for data_type in train dev; do
        
        echo "#####################################"
        echo "### EXTRACT IVECTORS ${data_type} ###"
        echo "#####################################"

        # dependencies: lots of src/ivectorbin
        sid/extract_ivectors.sh \
            --cmd './utils/run.pl' \
            --nj 4 \
            exp/extractor \
            data-${data_type} \
            exp/ivectors-${data_type}
    done
    
fi



if [ $stage -le 4 ]; then

    echo "### CREATE TRIALS FILE ###"
    spk_ivecs=./exp/ivectors-train/spk_ivector.scp
    utt_ivecs=./exp/ivectors-dev/ivector.scp
    
    trials=./exp/trials

    while read utt; do
        utt=( $utt );
        utt=${utt[0]}
        uttspk=(${utt//-/ })
        uttspk=${uttspk[0]}
        while read spk; do
            spk=( $spk );
            spk=${spk[0]};
            if [ "$spk" == "$uttspk" ]; then 
                echo $spk $utt "target" >> $trials;
            else
                echo $spk $utt "nontarget" >> $trials;
            fi
        done <$spk_ivecs;
    done <$utt_ivecs
fi

    

if [  $stage -le 5 ]; then
    
    echo "##################"
    echo "### TRAIN PLDA ###"
    echo "##################"

    plda_data_dir=data-train
    plda_ivec_dir=exp/ivectors-train
    
    utils/run.pl $plda_ivec_dir/log/plda.log \
           ivector-compute-plda \
           ark:$plda_data_dir/spk2utt \
           "ark:ivector-normalize-length scp:${plda_ivec_dir}/ivector.scp  ark:- |" \
           $plda_ivec_dir/plda \
        || exit 1;


    echo "##################"
    echo "### SCORE PLDA ###"
    echo "##################"
    
    mkdir -p exp/plda_scores/log
    
    utils/run.pl exp/plda_scores/log/plda_scoring.log \
           ivector-plda-scoring \
           --normalize-length=true \
           --simple-length-normalization=false \
           --num-utts=ark:${plda_ivec_dir}/num_utts.ark \
           "ivector-copy-plda --smoothing=0.0 ${plda_ivec_dir}/plda - |" \
           "ark:${plda_ivec_dir}/spk_ivector.ark" \
           "ark:ivector-normalize-length scp:./exp/ivectors-dev/ivector.scp ark:- |" \
           "cat '$trials' | cut -d\  --fields=1,2 |" \
           exp/plda_scores/plda_scores \
        || exit 1;

    eer=`compute-eer <(python local/prepare_for_eer.py $trials exp/plda_scores/plda_scores) 2> /dev/null`
    echo "EER == $eer"

fi



echo "END MAIN TRAIN SCRIPT: `date`"
