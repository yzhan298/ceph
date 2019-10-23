#!/bin/bash
set -ex

bs=131072 #4k: 4096 #128k: 131072 #4m: 4194304
os=131072 #4194304  #4096
qdepth=$1
totaltime=$2
parallel=1
#sampling_time=2 # second(s)
#skip_first_n_sampling_points=30 # time=2*30=60s

run_name=test_${qdepth}
osd_count=1
shard_count=1
temp=/tmp/load-ceph.$$

CURRENTDATE=`date +"%Y-%m-%d %T"`
#DATA_OUT_FILE="res_${qdepth}_${time}.csv"
DATA_OUT_FILE="dump-result.csv"

#shard_name=""
#for i in $(seq 0 $(expr $shard_count - 1)); do
#	shard_name+="opq_${i}_size "
#done

#printf "%s\n" ${CURRENTDATE} |  paste -sd ',' > ${DATA_OUT_FILE}
#printf '%s\n' "bs" "runtime" "concurrency" "throughput" "latency" |  paste -sd ',' >> ${DATA_OUT_FILE} 

sudo bin/ceph daemon osd.0 perf reset osd >/dev/null 2>/dev/null

do_dump() {
    file_rados_bench=./dump-rados-bench-${qdepth}*
    avg_throughput_rados_bench=$(grep "Bandwidth (MB/sec)" $file_rados_bench | awk '{print $3}')
    avg_lat_rados_bench=$(grep "Average Latency(s)" $file_rados_bench | awk '{print $3}')
	
    for o in $(seq 0 $(expr $osd_count - 1)) ; do
#	dump_opq="dump.op_queue"
#    	sudo bin/ceph daemon osd.${o} dump_op_pq_state 2>/dev/null | tee $dump_opq | jq 'map(.op_queue_size)' >$temp
#	opq_size=""
#	for s in $(seq 0 $(expr $shard_count - 1)) ; do
#		op_queue_size=$(jq ".[${s}]" $temp)
#		#echo "count-${count}.osd-${o}.shard-${s} : ${op_queue_size}"
#		opq_size+="${op_queue_size} "
#	done
        dump_state="dump.state.${qdepth}"
	sudo bin/ceph daemon osd.0 perf dump 2>/dev/null | tee $dump_state
	op_in_bytes=$(jq ".osd.op_in_bytes" $dump_state) # bytes from clients from m->get_recv_stamp() to now
	osd_op_lat=$(jq ".osd.op_latency.avgtime" $dump_state) # latency from m->get_recv_stamp() to now 
	
	printf '%s\n' $bs $totaltime $qdepth $avg_throughput_rados_bench $avg_lat_rados_bench | paste -sd ',' >> ${DATA_OUT_FILE}
done
}

sleep 5

for p in $(seq $parallel) ; do
    sudo bin/rados bench -p mybench -b ${bs} -o ${os} -t ${qdepth} --run-name=${run_name}_${p} ${totaltime} write --run-name ${run_name}-${p} --no-cleanup > dump-rados-bench-${qdepth}-${p}
done

wait
do_dump > dump_${qdepth}.txt
echo rados bench finished

