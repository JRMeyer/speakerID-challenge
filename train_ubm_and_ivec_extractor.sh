#!/bin/sh

# Joshua Meyer 2017
# <jrmeyer.github.io>

# INPUT (1) data_type (just going to be train unless
#                      you want to train on dev data lol)
#       (2) number of gaussian components
#       (3) number of dimensions in ivectors
#
# OUTPUT (1) exp/*

num_iters_ivec=4
num_iters_full_ubm=8


. parse_options.sh || exit 1;


if [ "$#" -ne 3 ]; then
    echo "$0:Illegal number of parameters"
    exit 1
fi

data_type=$1
num_components=$2
ivec_dim=$3

echo "##################################"
echo "### BEGIN TRAINING ${data_type}###"
echo "##################################"

# Now we're done with feature extraction... on to training!

mkdir ./exp

echo "### Training diag UBM ###"

sid/train_diag_ubm.sh \
    --cmd './utils/run.pl' \
    --nj 4 \
    data-${data_type} \
    $num_components \
    exp/diag_ubm_$num_components


echo "### Training full UBM ###"

sid/train_full_ubm.sh \
    --cmd './utils/run.pl' \
    --nj 4 \
    --num-iters $num_iters_full_ubm \
    data-${data_type} \
    exp/diag_ubm_$num_components \
    exp/full_ubm_$num_components


echo "### Training ivector extractor ###"

sid/train_ivector_extractor.sh \
    --cmd './utils/run.pl' \
    --nj 4 \
    --ivector-dim $ivec_dim \
    --num-iters $num_iters_ivec \
    exp/full_ubm_$num_components/final.ubm \
    data-${data_type} \
    exp/extractor



echo "################################"
echo "### END TRAINING ${data_type}###"
echo "################################"
