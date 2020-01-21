#!/bin/bash

#for io in 3200000 4800000 6400000 8000000 9600000 11200000 12800000; do
#for io in 3200000; do
#        sed -i "s/bluestore_throttle_bytes.*/bluestore_throttle_bytes = ${io}/g" ceph.conf
#        sed -i "s/bluestore_throttle_deferred_bytes.*/bluestore_throttle_deferred_bytes = ${io}/g" ceph.conf

#benchtool="rados" #accepting "rados" bench, "rbd" bench, "fio" bench
#for bt in "rados" "rbd" "fio"; do
for bt in "rados"; do
    printf '%s\n' "bs" "totaltime" "qdepth" "avg_kvq_size" "bluestore_kv_sync_lat" "bluestore_service_lat" "bluestore_kvq_lat" "bluestore_commit_lat" "bs_aio_wait_lat" "bs_kv_queued_lat" "bs_kv_committing_lat" "avg_rados_bench_throughput" "avg_rados_bench_lat" |  paste -sd ',' > result-single-dump.csv
    #for qd in 1 4 8 16 32 48 64 80 96 112 128 144 160 176 192 208 214 240 256; do
    #for qd in 1 4 8 16 32 48 64 80 96 112 128;do
    for qd in 128 128 128 128 128; do
	./run.sh $qd $bt
    done
    python plot_single_dump.py
    # move everything to a directory
    #dirname=${bt}-${io}-$(date +%F)
    dirname=${bt}-single-dump-$(date +"%Y_%m_%d_%I_%M_%p")
    mkdir -p ${dirname} # create data if not created
    mv dump* ${dirname} 
    mv result-single-dump.csv ${dirname}
    #mv ${dirname} ./data/
    #mkdir tio-${io}
    #mv dump* ./tio-${io}
    #mv result-single-dump.csv ./tio-${io}
    cp ceph.conf ${dirname}
    mv ${dirname} ./data
    #mv dump* data/.
    #mv result-single-dump.csv data/.
    #cp ceph.conf data/.
done

#done
