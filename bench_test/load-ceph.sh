#!/bin/bash

# parameters you may want to change

block_size=4096 # eric 1024
obj_size=4096
concurrent=32  #eric 2048 
parallel=8
run_time=360

# parameters that need to match ceph.conf

osd_count=1
shard_count=2 # eric 8

# no need to change these

pool=oiopool
run_name=oio_test
out_summary=oio_out
out_queue_size=oio_queue_size_out
# temp=/tmp/load-ceph.$$  #$$ represents process id  
			#$$ seems dangerous and is not encouraged to use.
temp=/tmp/load-ceph.

do_dump() {
    count=$1
    for o in $(seq 0 $(expr $osd_count - 1)) ; do
	bin/ceph daemon osd.${o} dump_op_pq_state 2>/dev/null | tee raw.${count}.${o} | jq 'map(.size)' >$temp
	for s in $(seq 0 $(expr $shard_count - 1)) ; do
	    size=$(jq ".[${s}]" $temp)
	    echo "${count}.${o}.${s} : ${size}"
	done
	rawperf="rawperf.${count}.${o}.osd"
	bin/ceph daemon osd.${o} perf dump osd 2>/dev/null >$rawperf
	bin/ceph daemon osd.${o} perf reset osd >/dev/null 2>/dev/null
	lat=$(jq ".osd.op_latency.avgtime" $rawperf)
	wlat=$(jq ".osd.op_w_latency.avgtime" $rawperf)
	echo "${count}.${o}#osd_op_latency : ${lat}"
	echo "${count}.${o}#osd_op_w_latency : ${wlat}"

	rawperf="rawperf.${count}.${o}.bluestore"
	bin/ceph daemon osd.${o} perf dump bluestore commit_lat 2>/dev/null >$rawperf
	bin/ceph daemon osd.${o} perf reset bluestore >/dev/null 2>/dev/null
	lat=$(jq ".bluestore.commit_lat.avgtime" $rawperf)
	echo "${count}.${o}#bluestore_commit_lat : ${lat}"
    done
}

# usage -- dump_queue_size 
timed_dump() {
    count=$1
    sleepsec=$2

    for i in $(seq $count) ; do
	sleep $sleepsec
	do_dump $i
    done
}

../src/stop.sh
../../my-vstart
# ../../my-new-vstart

sleep 10

# delete pool
bin/ceph osd pool delete $pool $pool --yes-i-really-really-mean-it

# create pool named data
bin/ceph osd pool create $pool 100 100

# number of datapoints to grab, every 15 seconds
samples=$(expr $run_time / 15 - 2)

echo "# sample.osd.shard : queue_size" > ${out_queue_size}
timed_dump $samples 15 >${out_queue_size} & 

echo STARTING RADOS BENCH
for p in $(seq $parallel) ; do
    bin/rados -b $block_size -o $obj_size -p $pool bench $run_time write -t $concurrent --no-cleanup --run-name ${run_name}-${p} >${out_summary}-${p} &
done

wait
echo FINISHED RADOS BENCH

../src/stop.sh

echo Done
