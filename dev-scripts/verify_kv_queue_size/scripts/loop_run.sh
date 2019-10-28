#!/bin/bash

#benchtool="rados" #accepting "rados" bench, "rbd" bench, "fio" bench
#for qd in 1 4 8 16 32 48 64 80 96 112 128 144 160 256; do
#for qd in 1 4 ;do
for bt in "rados" "rbd" "fio"; do
    for qd in 1 4 8 16 32 48 64 80 96 112 128; do
    #for qd in 1 4 ;do
	./run.sh $qd $bt
    done
    python plot_single_dump.py
    # move everything to a directory
    dirname=${bt}_plot_qd${qdepth}_$(date +%F)
    mkdir -p data/${dirname} # create data if not created
    mv dump* data/${dirname} 
    mv result-single-dump.csv data/${dirname}

done
