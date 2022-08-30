#!/bin/bash

#SBATCH --job-name="<<RUNNAME>>"
#SBATCH --partition=conroy,itc_cluster,shared
#SBATCH --constraint="intel"
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=12
#SBATCH -t <<RUNTIME>>
#SBATCH --mem 12000
#SBATCH -o <<RUNNAME>>.o
#SBATCH -e <<RUNNAME>>.e

export OMP_NUM_THREADS=12
cd <<DIRNAME>>
echo "SLURM JOB ID: $SLURM_JOB_ID"
date "+DATE: %Y-%m-%d%nTIME: %H:%M:%S"
./mk
./star inlist_project
date "+DATE: %Y-%m-%d%nTIME: %H:%M:%S"
