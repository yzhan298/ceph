#!/bin/bash

#benchtool="rados" #accepting "rados" bench, "rbd" bench, "fio" bench
#for qd in 1 4 8 16 32 48 64 80 96 112 128 144 160 256; do
#for qd in 1 4 ;do
#for bt in "rados" "rbd" "fio"; do
for bt in " rados "; do
    printf '%s\n' "bs" "totaltime" "qdepth" "avg_kvq_size" "avg_inflight_io_throttle" "bluestore_kv_sync_lat" "bluestore_service_lat" "bluestore_kvq_lat" "bluestore_commit_lat" "bs_aio_wait_lat" "bs_kv_queued_lat" "bs_kv_committing_lat" "avg_rados_bench_throughput" "avg_rados_bench_lat" |  paste -sd ',' > result-single-dump.csv
    for qd in 1 4 8 16 32 48 64 80 96 112 128 144 160 176 192 208 214 240 256; do
    #for qd in 1 8 16 32 64 96 128;do
    #for qd in 1 ; do
	./run.sh $qd $bt
    done
    python plot_single_dump.py
    # move everything to a directory
    #dirname=plot_${bt}_qd${qdepth}_$(date +%F)
    #mkdir -p ${dirname} # create data if not created
    #mv dump* ${dirname} 
    #mv result-single-dump.csv ${dirname}
    #mv ${dirname} ./data/
    mv dump* data/.
    mv result-single-dump.csv data/.
done
