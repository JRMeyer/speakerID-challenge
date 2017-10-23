#!/bin/sh

# Joshua Meyer 2017
# <jrmeyer.github.io>



# INPUT (1) the name of data_type (eg. train or dev)
#           this name must be the name of dir at audio_dir/data_type
#
# OUTPUT (1) feats-${data_type}/*

nj=4

. parse_options.sh || exit 1;


if [ "$#" -ne 1 ]; then
    echo "$0:Illegal number of parameters"
    exit 1
fi

data_type=$1


echo "#############################################"
echo "### BEGIN FEATURE EXTRACTION ${data_type} ###"
echo "#############################################"

echo "### MAKE MFCCs ###";

steps/make_mfcc.sh \
    --cmd './utils/run.pl' \
    --nj $nj \
    --mfcc-config "conf/mfcc.conf" \
    ./data-${data_type}\
    ./feats-${data_type}/log \
    ./feats-${data_type} \
    || printf "\n####\n#### ERROR: make_mfcc.sh \n####\n\n" \
    || exit 1;


echo "### MAKE VAD ###";

# we remove silence frames according to VAD (Matejka etal 2011)
sid/compute_vad_decision.sh \
    --cmd './utils/run.pl' \
    --nj $nj \
    --vad-config "conf/vad.conf" \
    ./data-${data_type} \
    ./feats-${data_type}/make_vad \
    ./feats-${data_type} \
    || printf "\n####\n#### ERROR: compute_vad_decision.sh \n####\n\n" \
    || exit 1;


./utils/fix_data_dir.sh ./data-${data_type}


echo "###########################################"
echo "### END FEATURE EXTRACTION ${data_type} ###"
echo "###########################################"
