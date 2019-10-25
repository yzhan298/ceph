#!/bin/bash

# running rbd bench 
sudo bin/rbd rm rbdbench/$RBD_IMAGE_NAME
sudo bin/ceph osd pool delete rbdbench rbdbench --yes-i-really-really-mean-it
sudo ../src/stop.sh
# for new ceph.conf
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -n -x -l --without-dashboard
# for existing ceph.conf
#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -k -x -l --without-dashboard

# create pool
sudo bin/ceph osd pool create rbdbench 150 150

# create rbd image
sudo bin/rbd create --size=10G rbdbench/$RBD_IMAGE_NAME

# rbd cache = false/true may bring huge difference

sampling_time=2 # second(s)
skip_first_n_sampling_points=30 # time=2*30=60s

run_name=test_${qdepth}
osd_count=1
shard_count=1
temp=/tmp/load-ceph.$$

RBD_IMAGE_NAME="bench1"
iotype="write"
iosize="128K"
iothread=$1
iototal=$2
iopattern="rand"

CURRENTDATE=`date +"%Y-%m-%d %T"`
#DATA_OUT_FILE="res_${qdepth}_${time}.csv"
DATA_OUT_FILE="dump-rbd-result.csv"

shard_name=""
for i in $(seq 0 $(expr $shard_count - 1)); do
	shard_name+="opq_${i}_size "
done

printf "%s\n" ${CURRENTDATE} |  paste -sd ',' > ${DATA_OUT_FILE}
printf '%s\n' "bs" "runtime" "concurrency" "throughput" "latency" $shard_name |  paste -sd ',' >> ${DATA_OUT_FILE} 

sudo bin/ceph daemon osd.0 perf reset osd >/dev/null 2>/dev/null

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
	osd_runtime=$( echo "$endtime - $starttime" | bc -l )
	osd_throughput=$(expr $op_in_bytes/1048576/$osd_runtime | bc -l)
	
	printf '%s\n' $bs $totaltime $qdepth $osd_throughput $osd_op_lat $opq_size | paste -sd ',' >> ${DATA_OUT_FILE}
done
}

time_dump() {
    count=$1
    sleepsec=$2
    for i in $(seq $count) ; do
        sleep $sleepsec
	if [ $i -lt $skip_first_n_sampling_points ]; then
		continue
	fi
	do_dump $i
done
}

sleep 5

starttime=`date +%s.%N`

samples=$(expr $totaltime/${sampling_time} | bc -l)
time_dump $samples $sampling_time > dump &

sudo bin/rbd -p rbdbench bench $RBD_IMAGE_NAME --io-type $iotype --io-size $iosize --io-threads $iothread --io-total $iototal --io-pattern $iopattern 2>&1 | tee  dump-rbd-bench &

wait

echo rbd bench finished
