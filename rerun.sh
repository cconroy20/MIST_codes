#!/bin/bash

# syntax: ./rerun.sh dir
 
#set up MESA SDK
source $MESASDK_ROOT/bin/mesasdk_init.sh

dir=$1

tarr=(`ls $MIST_GRID_DIR/$dir`)
tlen=${#tarr[*]}

#this restricts to M<=3.9
tlen=50

for j in `seq 1 $tlen`; do

    mdir=${tarr[$j-1]}

    #check that model has a TP-AGB photo
    if [ -f $MIST_GRID_DIR/$dir/$mdir/photos/TPAGB_photo ]; then

	echo $mdir

	#move into working directory
	cd $MIST_GRID_DIR/$dir/$mdir

	#save existing rse
	/bin/mv src/run_star_extras.f90 src/run_star_extras.orig

	#copy over files necessary for restart
	/bin/cp $MIST_CODE_DIR/restart/mk .
	/bin/cp $MIST_CODE_DIR/restart/re .
	/bin/cp $MIST_CODE_DIR/restart/src/* src/

	#change history file in inlist
	/bin/cp inlist_project inlist
	sed -i 's/M.data/M_TPAGB.data/g' inlist

	#create new run script
	head=${mdir/_dir//}
	head=${head////}
	newf=${head}_run_TPAGB.sh
	/bin/cp ${head}_run.sh $newf

	#edit run script
	sed -i 's/48/72/g' $newf
	sed -i 's/M.o/M_TPAGB.o/g' $newf
	sed -i 's/M.e/M_TPAGB.e/g' $newf
	sed -i 's/star inlist_project/re TPAGB_photo/g' $newf

	#submit restart
	sbatch $newf

    fi

done

