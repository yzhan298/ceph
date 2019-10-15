#!/bin/bash
#set -ex

bs=4096 #4k: 4096 #128k: 131072 #4m: 4194304
os=4096 #4194304  #4096
qdepth=$1
time=300 #5mins=300
parallel=1
sampling_time=2 # second(s)

run_name=test_${qdepth}
osd_count=1
shard_count=5
temp=/tmp/load-ceph.$$

CURRENTDATE=`date +"%Y-%m-%d %T"`
#DATA_OUT_FILE="res_${qdepth}_${time}.csv"
DATA_OUT_FILE="result_${CURRENTDATE}.csv"
printf "%s\n" ${CURRENTDATE} |  paste -sd ',' > ${DATA_OUT_FILE}
printf '%s\n' "bs" "runtime" "concurrency" "throughput" "latency" |  paste -sd ',' >> ${DATA_OUT_FILE} 

sudo bin/ceph daemon osd.0 perf reset osd >/dev/null 2>/dev/null

do_dump() {
    count=$1
    endtime=`date +%s.%N`
    for o in $(seq 0 $(expr $osd_count - 1)) ; do
	dump_opq="dump.op_queue.${count}"
    	sudo bin/ceph daemon osd.${o} dump_op_pq_state 2>/dev/null | tee $dump_opq | jq 'map(.op_queue_size)' >$temp
	for s in $(seq 0 $(expr $shard_count - 1)) ; do
		op_queue_size=$(jq ".[${s}]" $temp)
		echo "count-${count}.osd-${o}.shard-${s} : ${op_queue_size}"
	done
        dump_state="dump.state.${count}"
	sudo bin/ceph daemon osd.0 perf dump 2>/dev/null | tee $dump_state

	printf '%s\n' $bs $time $qdepth | paste -sd ',' >> ${DATA_OUT_FILE}
done
}

time_dump() {
    count=$1
    sleepsec=$2
    for i in $(seq $count) ; do
        sleep $sleepsec
	do_dump $i
done
}

sleep 5

starttime=`date +%s.%N`

samples=$(expr $time/2 | bc -l)
time_dump $samples $sampling_time > dump &

for p in $(seq $parallel) ; do
    sudo bin/rados bench -p mybench -b ${bs} -o ${os} -t ${qdepth} --run-name=${run_name}_${p} ${time} write --run-name ${run_name}-${p} --no-cleanup > rados-bench-${qdepth}-${p} &
done

wait

echo rados bench finished

