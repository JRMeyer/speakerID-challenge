#!/bin/sh

# Joshua Meyer 2017
# <jrmeyer.github.io>


# INPUT (1) a dir of audio
#       (2) the name of data_type (eg. train or dev)
#           this name must be the name of dir at audio_dir/data_type
#
# OUTPUT (1) data-${data_type}/wav.scp
#        (2) data-${data_type}/utt2spk
#        (3) data-${data_type}/spk2utt
#
#        (4) feats-${data_type}/*


if [ "$#" -ne 2 ]; then
    echo "$0:Illegal number of parameters"
    exit 1
fi

audio_dir=$1
data_type=$2


echo "####################################"
echo "### BEGIN DATA PREP ${data_type} ###"
echo "####################################"

echo "Creating data dir in ./data-${data_type}"
echo "Creating feats dir in ./feats-${data_type}"
rm -rf ./feats-${data_type} ./data-${data_type}
mkdir -p ./feats-${data_type}/log ./data-${data_type}

## Convert flac to wav and downsample
# for i in ./train/*.flac; do filename=${i##*/}; basename=${filename%.flac}; sox $i ./train-wav/${basename}.wav; done
# for i in ./train-wav/*.wav; do filename=${i##*/}; sox $i -r 8k ./tmp/$filename; done

# this is an if loop that takes care of the variation in our datasets
# because our eval has no speaker info, but we need an utt2spk and
# spk2utt all the same. This loop also will create the wav.scp file
# needed.
if [ -f ${audio_dir}/${data_type}/utt2spk ]; then
    # Create wav.scp and spk2utt
    echo "Found utt2spk in ${audio_dir}/${data_type}/, using it."
    
    cp ${audio_dir}/${data_type}/utt2spk ./data-${data_type}/utt2spk
    utils/utt2spk_to_spk2utt.pl ./data-${data_type}/utt2spk > ./data-${data_type}/spk2utt
    
    ext=wav
    for abspath in `find ${audio_dir}/${data_type}/*`; do
        filename=${abspath##*/}
        echo "${filename%.${ext}} ${abspath}" >> ./data-${data_type}/wav.scp
    done
    
else
    # Create wav.scp, utt2spk, and spk2utt
    echo "Assuming ZERO info on speakers, and treating each utt"
    echo "as having a different speaker."
    
    ext=wav
    for abspath in `find ${audio_dir}/${data_type}/*`; do
        filename=${abspath##*/}
        echo "${filename%.${ext}} ${abspath}" >> ./data-${data_type}/wav.scp
        # our test data has no speaker info, so just make these 2 files
        # to make utils/validate_data_dir.sh happy
        echo "${filename%.${ext}} ${filename%.${ext}}" >> ./data-${data_type}/spk2utt
        echo "${filename%.${ext}} ${filename%.${ext}}" >> ./data-${data_type}/utt2spk
    done
fi


# sort files to make kaldi happy
for f in ./data-${data_type}/*; do
    LC_ALL=C sort -i $f -o $f;
done

./utils/fix_data_dir.sh ./data-${data_type}

        
echo "##################################"
echo "### END DATA PREP ${data_type} ###"
echo "##################################"
