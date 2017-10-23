#!/bin/sh

# INPUT (1) plda_products
#
# OUTPUT (1) RESULTS.txt

# Joshua Meyer 2017
# <jrmeyer.github.io>


if [ "$#" -ne 1 ]; then
    echo "$0:Illegal number of parameters"
    exit 1
fi

plda_products=$1


best_plda=-100
best_id=''
current_utt=''
line_num=0

while read line; do
    
    line=( $line )
    cur_plda=${line[2]}
    cur_id=${line[0]}
    
    if [ "${line[1]}" == "$current_utt" ]; then
        if (( $(echo ${cur_plda}'>'${best_plda} | bc -l) )); then
            best_plda=$cur_plda
            best_id=$cur_id
        fi
        
    else
        # if we've reached a new utterance, print our label decision and
        # reset current utterance and best utterance score
        if [ $line_num -ne 0 ]; then
            # but don't print first pass, without any info
            echo "${current_utt} has been labeled as ${best_id} (${best_plda})" >> ./exp/RESULTS.txt
        fi
        
        current_utt=${line[1]}
        best_plda=-100
        
        if (( $(echo ${cur_plda}'>'${best_plda} | bc -l) )); then
            best_plda=$cur_plda
            best_id=$cur_id
        fi
        
    fi
    
    ((line_num++))

done <${plda_products}

echo $best_id
