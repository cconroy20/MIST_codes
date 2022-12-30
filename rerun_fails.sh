#!/bin/bash

# syntax: ./rerun_fails.sh dir
 
#set up MESA SDK
source $MESASDK_ROOT/bin/mesasdk_init.sh

#input directory
dir=$1

#get list of EEPs
eepdir=$STORE_DIR/consistent/$dir/eeps/
tarr=(`ls $eepdir`)
tlen=${#tarr[*]}

echo $dir
echo "N="$tlen
echo 

#extract [Fe/H]
if [ ${dir:4:1} == 'm' ]; then
    feh='-'${dir:5:3}
else
    feh=${dir:5:3}
fi
feh=$(echo "scale=2; ${feh}/100" | bc)

#extract [a/Fe]
if [ ${dir:13:2} == 'm2' ]; then afe='-0.2'; fi
if [ ${dir:13:2} == 'p0' ]; then afe='+0.0'; fi
if [ ${dir:13:2} == 'p2' ]; then afe='+0.2'; fi
if [ ${dir:13:2} == 'p4' ]; then afe='+0.4'; fi
if [ ${dir:13:2} == 'p6' ]; then afe='+0.6'; fi


for j in `seq 1 $tlen`; do

    len=$( wc -l < $eepdir/${tarr[$j-1]})

    mm=${tarr[$j-1]}
    mm=${mm/M.track.eep/}
    mm=$(echo "scale=2; ${mm}/100" | bc)

    #intermediate-mass models
  #  if (( $(echo "$mm > 0.60 && $mm < 4.0" | bc) )); then
    if (( $(echo "$mm >= 1.2 && $mm < 4.0" | bc) )); then
  #  if (( $(echo "$mm >= 4.0 && $mm < 7.0" | bc) )); then

        if [ $len -lt 1421 ]; then

            echo $mm $len

	    #try re-running the model
	    mnew1=${mm}
	    #small mass perturbation
            mnew2=$(echo "scale=2; ${mm} + 0.01" | bc)

	    ./submit_jobs.py   $feh   $afe    0.40    MIST2_49_li7.net     vvcrit0.4     CUSTOM  $mnew1,$mnew2

        fi
    fi

    #high-mass models
   # if (( $(echo "$mm >= 7.0" | bc) )); then
    if (( $(echo "$mm >= 7000.0" | bc) )); then

	if [ $len -lt 820 ]; then
	    
	    echo $mm $len

	    if (( $(echo "$mm <= 20.0" | bc) )); then
		mnew1=$(echo "scale=2; ${mm} + 0.1" | bc)
		mnew2=$(echo "scale=2; ${mm} - 0.1" | bc)
	    else
		mnew1=$(echo "scale=2; ${mm} + 1.0" | bc)
		mnew2=$(echo "scale=2; ${mm} - 1.0" | bc)
	    fi

	    ./submit_jobs.py   $feh   $afe    0.40    MIST2_49_li7.net     vvcrit0.4     CUSTOM  $mnew1,$mnew2

	fi
    fi
    
done

