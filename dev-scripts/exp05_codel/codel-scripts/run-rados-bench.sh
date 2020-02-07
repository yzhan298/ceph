#!/bin/bash
# run rados bench and collect result
bs=4096 #block size or object size (Bytes)
totaltime=60 # running time (seconds)

# no need to change
osd_count=1            	 	# number of OSDs
shard_count=1           	# number of sharded op_queue
DATA_FILE=dump-codel-tests.csv  # output file name
pool="mybench"

single_dump() {
    qdepth=$1
    for o in $(seq 0 $(expr $osd_count - 1)) ; do
        dump_state="dump-state-${qdepth}"
        sudo bin/ceph daemon osd.0 perf dump 2>/dev/null | tee $dump_state
        #op_in_bytes=$(jq ".osd.op_in_bytes" $dump_state) # bytes from clients from m->get_recv_stamp() to now
        #osd_op_lat=$(jq ".osd.op_latency.avgtime" $dump_state) # latency from m->get_recv_stamp() to now
        #kvq_size=$(jq ".bluestore.bluestore_kv_queue_size" $dump_state)
        #avg_kvq_size=$(jq ".bluestore.bluestore_kv_queue_avg_size" $dump_state)
        avg_throughput_bench=$(grep "Bandwidth (MB/sec)" dump-rados-bench-${qdepth} | awk '{print $3}')
        avg_lat_bench=$(grep "Average Latency(s)" dump-rados-bench-${qdepth} | awk '{print $3}')
        bluestore_kv_sync_lat=$(jq ".bluestore.kv_sync_lat.avgtime" $dump_state)
        bluestore_kvq_lat=$(jq ".bluestore.bluestore_kvq_lat.avgtime" $dump_state)
        printf '%s\n' $bs $totaltime $qdepth $bluestore_kv_sync_lat $bluestore_kvq_lat $avg_throughput_bench $avg_lat_bench  | paste -sd ',' >> ${DATA_FILE}
done
}

printf '%s\n' "bs" "totaltime" "qdepth" "bluestore_kv_sync_lat" "bluestore_kvq_lat" "avg_rados_bench_throughput" "avg_rados_bench_lat" |  paste -sd ',' > ${DATA_FILE}
#for qd in 1 16 32 48 64 80 96 112 128;do
#for qd in 1 16 32 48 64 80 96; do
for qd in 1 16 32 64; do
        #./run.sh $qd $bt
        sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -k -x -l --without-dashboard
        sudo bin/ceph osd pool create $pool 128 128
        
        echo benchmark starts!
        sudo bin/rados bench -p mybench -b ${bs} -o ${bs} -t ${qd} ${totaltime} write --no-cleanup > dump-rados-bench-${qd}
        single_dump $qd
        echo benchmark stops!

        echo time series plot start!
        awk '{print $5}' out/osd.0.log | grep current_blocking_dur | grep -Eo '[+-]?[0-9]+([.][0-9]+)?' | tr ' ' ',' > dump-block-dur-${qd}.csv
        export PLOTOUTNAME="dump-block-dur-${qd}.png"
        export PLOTINNAME="dump-block-dur-${qd}.csv"
        python plot_codel.py 
        echo time series plot stops!

        sudo bin/ceph osd pool delete $pool $pool --yes-i-really-really-mean-it
        sudo ../src/stop.sh
done
python plot_codel.py
# move everything to a directory
dn=codel-tests-$(date +"%Y_%m_%d_%I_%M_%p")
mkdir -p ${dn} # create data if not created
mv dump* ${dn}
cp ceph.conf ${dn}
mv ${dn} ./data
echo DONE!

