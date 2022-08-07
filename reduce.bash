#!/bin/bash

dir=$1

#root=/n/conroyfs1/dotter/MIST2/v2

if [ -d $1 ]
then
  cd $1

  mkdir tracks
  mkdir eeps
  mkdir isochrones

  for f in *M_dir
  do
    mv $f/LOGS/*history.data tracks/
  done
fi
