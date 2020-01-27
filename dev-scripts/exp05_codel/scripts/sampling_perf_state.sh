#!/bin/bash
set -ex

# common setting
bs=1048576 #4k: 4096 #128k: 131072 #4m: 4194304
qdepth=$1
benchtool=$2

# rados bench setting
totaltime=60 # seconds
parallel=1
sampling_time=2 # second(s)
skip_first_n_sampling_points=2 # time=2*30=60s

# RBD bench setting
RBD_IMAGE_NAME="bench1"
iotype="write"
iototal="10M"
iopattern="seq" #rand or seq

# FIO bench setting
rw="randwrite" #write 表示顺序写，randwrite 表示随机写，read 表示顺序读，randread 表示随机读
if [ $benchtool = "fio" ]
then
    sed -i "s/iodepth=.*/iodepth=${qdepth}/g" fio_write.fio
    sed -i "s/runtime=.*/runtime=${totaltime}/g" fio_write.fio
    sed -i "s/bs=.*/bs=${bs}/g" fio_write.fio
    sed -i "s/rw=.*/rw=${rw}/g" fio_write.fio
fi

run_name=test_${qdepth}
osd_count=1  		# number of OSDs
shard_count=1   	# number of sharded op_queue
temp=/tmp/load-ceph.$$

CURRENTDATE=`date +"%Y-%m-%d %T"`
#DATA_OUT_FILE="res_${qdepth}_${time}.csv"
DATA_OUT_FILE="dump-result-sampling.csv"
DATA_TOTAL_FILE="result-single-dump.csv"
CPU_MEM_DATA="dump-cpu-mem.csv"

# average in-flight IO getting from throttler
avg_inflight_io_throttle=0
# get avg throughput from benchmark tool
avg_throughput_bench=0
# get avg lat from benchmark tool
avg_lat_bench=0

shard_name=""
for i in $(seq 0 $(expr $shard_count - 1)); do
	shard_name+="opq_${i}_size "
done

printf "%s\n" ${CURRENTDATE} |  paste -sd ',' > ${DATA_OUT_FILE}
printf '%s\n' "bs" "runtime" "concurrency" $shard_name "kvq_size" "avg_kvq_size" "throttle_inflight_ios" "throttle_deferred_inflight_ios" |  paste -sd ',' >> ${DATA_OUT_FILE} 

printf "%s\n" ${CURRENTDATE} |  paste -sd ',' > ${CPU_MEM_DATA}
printf '%s\n' "total memory(KB)" "used memory(KB)" "free memory(KB)" "used CPU(%)" |  paste -sd ',' >> ${CPU_MEM_DATA}
#printf '%s\n' "bs" "runtime" "concurrency" $shard_name "kvq_size" "avg_kvq_size" "bs_kv_sync_lat" "bs_service_lat" |  paste -sd ',' >> ${DATA_TOTAL_FILE}

sudo bin/ceph daemon osd.0 perf reset osd >/dev/null 2>/dev/null

# do_dump is for sampling. Change sampling_time to control sampling rate
do_dump() {
    count=$1
    endtime=`date +%s.%N`
    for o in $(seq 0 $(expr $osd_count - 1)) ; do
	dump_opq="dump.op_queue.${count}"
    	sudo bin/ceph daemon osd.${o} dump_op_pq_state 2>/dev/null | tee $dump_opq | jq 'map(.op_queue_size)' >$temp
	opq_size=""
	for s in $(seq 0 $(expr $shard_count - 1)) ; do
		op_queue_size=$(jq ".[${s}]" $temp)
		#echo "count-${count}.osd-${o}.shard-${s} : ${op_queue_size}"
		opq_size+="${op_queue_size} "
	done
        dump_state="dump.state.${count}"
	sudo bin/ceph daemon osd.0 perf dump 2>/dev/null | tee $dump_state
	op_in_bytes=$(jq ".osd.op_in_bytes" $dump_state) # bytes from clients from m->get_recv_stamp() to now
	osd_op_lat=$(jq ".osd.op_latency.avgtime" $dump_state) # latency from m->get_recv_stamp() to now 

	#osd_runtime=$( echo "$endtime - $starttime" | bc -l )
	#osd_throughput=$(expr $op_in_bytes/1048576/$osd_runtime | bc -l)
	# BlueStore
	kvq_size=$(jq ".bluestore.bluestore_kv_queue_size" $dump_state)
	avg_kvq_size=$(jq ".bluestore.bluestore_kv_queue_avg_size" $dump_state)
	throttle_direct_inflight_ios=$(jq '."throttle-bluestore_throttle_bytes".inflight_ios' $dump_state)
	avg_inflight_io_throttle=$( echo $avg_inflight_io_throttle+$throttle_direct_inflight_ios | bc)
	throttle_deferred_inflight_ios=$(jq '."throttle-bluestore_throttle_deferred_bytes".inflight_ios' $dump_state)	
	printf '%s\n' $bs $totaltime $qdepth $opq_size $kvq_size $avg_kvq_size $throttle_direct_inflight_ios $throttle_deferred_inflight_ios  | paste -sd ',' >> ${DATA_OUT_FILE}
done
}

# single_dump is for collecting average values. One dump when benchmark finishes.
single_dump() {
    for o in $(seq 0 $(expr $osd_count - 1)) ; do
	#dump_opq="dump.op_queue.single"
    	#sudo bin/ceph daemon osd.${o} dump_op_pq_state 2>/dev/null | tee $dump_opq | jq 'map(.op_queue_size)' >$temp
	#opq_size=""
	#for s in $(seq 0 $(expr $shard_count - 1)) ; do
	#	op_queue_size=$(jq ".[${s}]" $temp)
	#	#echo "count-${count}.osd-${o}.shard-${s} : ${op_queue_size}"
	#	opq_size+="${op_queue_size} "
	#done
        dump_state="dump.state.single"
	sudo bin/ceph daemon osd.0 perf dump 2>/dev/null | tee $dump_state
	op_in_bytes=$(jq ".osd.op_in_bytes" $dump_state) # bytes from clients from m->get_recv_stamp() to now
	osd_op_lat=$(jq ".osd.op_latency.avgtime" $dump_state) # latency from m->get_recv_stamp() to now 

	#osd_runtime=$( echo "$endtime - $starttime" | bc -l )
	#osd_throughput=$(expr $op_in_bytes/1048576/$osd_runtime | bc -l)
	# BlueStore
	kvq_size=$(jq ".bluestore.bluestore_kv_queue_size" $dump_state)
	avg_kvq_size=$(jq ".bluestore.bluestore_kv_queue_avg_size" $dump_state)
	if [ $benchtool = "rados" ];then 
		avg_throughput_bench=$(grep "Bandwidth (MB/sec)" dump-rados-bench-* | awk '{print $3}')
		avg_lat_bench=$(grep "Average Latency(s)" dump-rados-bench-* | awk '{print $3}')
	fi
	#if [ $benchtool = "fio" ];then
	#
	#fi
	bluestore_kv_sync_lat=$(jq ".bluestore.kv_sync_lat.avgtime" $dump_state)
	bluestore_service_lat=$(jq ".bluestore.bluestore_service_lat.avgtime" $dump_state)
	bluestore_kvq_lat=$(jq ".bluestore.bluestore_kvq_lat.avgtime" $dump_state)
	bluestore_commit_lat=$(jq ".bluestore.commit_lat.avgtime" $dump_state)
	bs_aio_wait_lat=$(jq ".bluestore.state_aio_wait_lat.avgtime" $dump_state)
	bs_kv_queued_lat=$(jq ".bluestore.state_kv_queued_lat.avgtime" $dump_state)
	bs_kv_committing_lat=$(jq ".bluestore.state_kv_commiting_lat.avgtime" $dump_state)
	printf '%s\n' $bs $totaltime $qdepth $avg_kvq_size $bluestore_kv_sync_lat $bluestore_service_lat $bluestore_kvq_lat $bluestore_commit_lat $bs_aio_wait_lat $bs_kv_queued_lat $bs_kv_committing_lat $avg_throughput_bench $avg_lat_bench  | paste -sd ',' >> ${DATA_TOTAL_FILE}
done
}

# get cpu and memory usage
do_cpu_mem_dump() {
	# get total memory (KB)
	totalmem=$(free | grep Mem | awk '{print $2}')

	# get used memory (KB)
	usedmem=$(free | grep Mem | awk '{print $3}')

	# get free memory (KB)
	freemem=$(free | grep Mem | awk '{print $4}')

	# get used CPU (%)
	usedcpu=$(iostat | awk 'NR == 4 {print $1}')

	printf '%s\n' $totalmem $usedmem $freemem $usedcpu | paste -sd ',' >> ${CPU_MEM_DATA}
}

# time_dump controls the rate of sampling. NOT use for avg latency.
# ONLY use this when do_dump() for sampling.
time_dump() {
    count=$1
    sleepsec=$2
    for i in $(seq $count) ; do
        sleep $sleepsec
	if [ $i -lt $skip_first_n_sampling_points ]; then
		continue
	fi
	do_dump $i
	do_cpu_mem_dump
done
}

sleep 5

starttime=`date +%s.%N`

# execute sampling
#samples=$(expr $totaltime/${sampling_time}-7 | bc -l)
#time_dump $samples $sampling_time > dump &

# BENCHMARKING
for p in $(seq $parallel) ; do
    # rados bench
   case $benchtool in
	"rados")
		sudo bin/rados bench -p mybench -b ${bs} -o ${bs} -t ${qdepth} --run-name=${run_name}_${p} ${totaltime} write --run-name ${run_name}-${p} --no-cleanup > dump-rados-bench-${qdepth}-${p} &
	;;
	"rbd")
		sudo bin/rbd -p mybench bench $RBD_IMAGE_NAME --io-type $iotype --io-size $bs --io-threads $qdepth --io-total $iototal --io-pattern $iopattern 2>&1 | tee  dump-rbd-bench-${qdepth}-${p} & 
	;;
	"fio")
		sudo fio fio_write.fio > dump-fio-bench-${qdepth}-${p} &
	;;
    esac
done

wait

# calculate related data
# TODO doesn't work FIXIT 
avg_inflight_io_throttle=$( echo $avg_inflight_io_throttle/$samples | bc)
# single dump state
single_dump > dump_${qdepth}.txt

echo benchmark finished

