#!/bin/bash

#SBATCH --job-name="<<RUNNAME>>"
#SBATCH --partition=conroy,itc_cluster
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
./mk
./star inlist_project
