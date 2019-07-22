#!/bin/bash

set -ex

bs=4194304 #4k: 4096 #128k: 131072 #4m: 4194304
os=4194304 #4194304  #4096
qdepth=$1
time=10
parallel=1

run_name=t_test
osd_count=1
shard_count=2
temp=/tmp/load-ceph.$$

CURRENTDATE=`date +"%Y-%m-%d %T"`
#DATA_OUT_FILE="res_${qdepth}_${time}.csv"
DATA_OUT_FILE="result_ssd.csv"

#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
#sudo ../src/stop.sh
#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -n -x -l -b

#create a pool
#sudo bin/ceph osd pool create mybench 150 150


do_dump() {

  #get data from rados_bench dump
  #rados_bench_${qdepth}.txt
  file_rados_bench=./rados_bench_${qdepth}.txt
  avg_throughput_rados_bench=$(grep "Bandwidth (MB/sec)" $file_rados_bench | awk '{print $3}') 
  avg_lat_rados_bench=$(grep "Average Latency(s)" $file_rados_bench | awk '{print $3}')

  count=$1
  #dump sharded op queue size
  for o in $(seq 0 $(expr $osd_count - 1)) ; do
    #dump_opq="dump.op_queue.${count}"
    #sudo bin/ceph daemon osd.0 dump_op_pq_state 2>/dev/null | tee $dump_opq
    #sudo bin/ceph daemon osd.0 dump_op_pq_state 2>/dev/null | tee $dump_opq | jq 'map(.size)' >$temp
    #for  s in $(seq 0 $(expr $shard_count - 1)) ; do
    #  size=$(jq ".[${s}]" $temp)
    #  echo "${count}.${o}.${s} : ${size}"
    #done
    dump_op_queue="dump.op_queue.${count}"
    sudo bin/ceph daemon osd.0 perf dump 2>/dev/null | tee $dump_op_queue
    op_queue_0_size=$(jq ".opshard0.opwq_size" $dump_op_queue)
    op_queue_1_size=$(jq ".opshard1.opwq_size" $dump_op_queue)
    op_queue_2_size=$(jq ".opshard2.opwq_size" $dump_op_queue)
    op_queue_3_size=$(jq ".opshard3.opwq_size" $dump_op_queue)
    op_queue_4_size=$(jq ".opshard4.opwq_size" $dump_op_queue)
    op_queue_5_size=$(jq ".opshard5.opwq_size" $dump_op_queue)
    op_queue_6_size=$(jq ".opshard6.opwq_size" $dump_op_queue)
    op_queue_7_size=$(jq ".opshard7.opwq_size" $dump_op_queue)

    op_queue_0_lat=$(jq ".opshard0.opwq_enq_to_deq_lat.avgtime" $dump_op_queue)
    op_queue_1_lat=$(jq ".opshard1.opwq_enq_to_deq_lat.avgtime" $dump_op_queue)
    op_queue_2_lat=$(jq ".opshard2.opwq_enq_to_deq_lat.avgtime" $dump_op_queue)
    op_queue_3_lat=$(jq ".opshard3.opwq_enq_to_deq_lat.avgtime" $dump_op_queue)
    op_queue_4_lat=$(jq ".opshard4.opwq_enq_to_deq_lat.avgtime" $dump_op_queue)
    op_queue_5_lat=$(jq ".opshard5.opwq_enq_to_deq_lat.avgtime" $dump_op_queue)
    op_queue_6_lat=$(jq ".opshard6.opwq_enq_to_deq_lat.avgtime" $dump_op_queue)
    op_queue_7_lat=$(jq ".opshard7.opwq_enq_to_deq_lat.avgtime" $dump_op_queue)
    op_queue_lat_sum=`expr $op_queue_0_lat+$op_queue_1_lat+$op_queue_2_lat+$op_queue_3_lat+$op_queue_4_lat+$op_queue_5_lat+$op_queue_6_lat+$op_queue_7_lat | bc -l`
    op_queue_lat_avg=`expr $op_queue_lat_sum/8 | bc -l`

    

    dump_osd="dump.osd.${count}"
    sudo bin/ceph daemon osd.0 perf dump osd 2>/dev/null | tee $dump_osd
    sudo bin/ceph daemon osd.0 perf reset osd >/dev/null 2>/dev/null
    op_lat=$(jq ".osd.op_latency.avgtime" $dump_osd) # client io latency
    op_bw=$(jq ".osd.op_in_bytes" $dump_osd) # client io throughput 
    op_throughput=$(expr $op_bw/1048576/$time | bc -l) # client io throughput
    #echo "#op_latency : $op_lat, op_throughput=$(expr $op_bw/1048576/$time | bc -l)"
    op_time_of_finding_obc_in_do_op=$(jq ".osd.time_of_finding_obc_in_do_op.avgtime" $dump_osd) # time of finding object context (metadata)
    op_prepare_lat=$(jq ".osd.op_prepare_latency.avgtime" $dump_osd) # time from dequeue to end of execute_ctx()
    
    
    dump_bluestore="dump.bs.${count}"
    #sudo bin/ceph daemon osd.0 perf dump bluestore commit_lat 2>/dev/null | tee $dump_bluestore
    sudo bin/ceph daemon osd.0 perf dump bluestore 2>/dev/null | tee $dump_bluestore
    sudo bin/ceph daemon osd.0 perf reset bluestore >/dev/null 2>/dev/null
    kv_flush_lat=$(jq ".bluestore.kv_flush_lat.avgtime" $dump_bluestore)
    kv_commit_lat=$(jq ".bluestore.kv_commit_lat.avgtime" $dump_bluestore)
    kv_lat=$(jq ".bluestore.kv_lat.avgtime" $dump_bluestore)
    state_prepare_lat=$(jq ".bluestore.state_prepare_lat.avgtime" $dump_bluestore)
    state_aio_wait_lat=$(jq ".bluestore.state_aio_wait_lat.avgtime" $dump_bluestore)
    state_io_done_lat=$(jq ".bluestore.state_io_done_lat.avgtime" $dump_bluestore)
    kv_queue_size=$(jq ".bluestore.bluestore_kv_queue_size" $dump_bluestore) # the total kv_queue size
    osr_blocking_count=$(jq ".bluestore.bluestore_osr_blocking_count" $dump_bluestore) # # of blockings within osr
    bs_commit_lat=$(jq ".bluestore.commit_lat.avgtime" $dump_bluestore) # time from TransContext’s creation to destruction
    bs_submit_lat=$(jq ".bluestore.submit_lat.avgtime" $dump_bluestore) # time from queue_transaction begin to end, average submit latency 
    #echo "#bluestore_kv_lat : ${kv_lat}"
  done  
  #rados_bench_thp=
  #rados_bench_lat=
  #printf "%s\n" ${CURRENTDATE} |  paste -sd ',' >> ${DATA_OUT_FILE}
  #printf '%s\n' "bs" "runtime" "client_qd" "op_thput" "op_lat" "kv_flush_lat" "kv_commit_lat" "kv_lat" "state_prepare_lat" "aio_wait_lat" "io_done_lat" |  paste -sd ',' >> ${DATA_OUT_FILE}
  printf '%s\n' $bs $time $qdepth $op_throughput $avg_throughput_rados_bench $op_lat $avg_lat_rados_bench $op_time_of_finding_obc_in_do_op $op_prepare_lat $kv_flush_lat $kv_commit_lat $kv_lat $state_prepare_lat $state_aio_wait_lat $state_io_done_lat $kv_queue_size $osr_blocking_count $bs_commit_lat $bs_submit_lat $op_queue_lat_avg | paste -sd ',' >> ${DATA_OUT_FILE}
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

#samples=$(expr $time / 5 | bc -l)
#time_dump $samples 5 > dump.result &

#rados bench
#sudo echo 3 | sudo tee /proc/sys/vm/drop_caches && sudo sync
#sudo CEPH_ARGS="--log-file log_radosbench --debug-ms 1" bin/rados bench -p mybench -c ceph.conf -b ${bs} -o ${os} -t ${qdepth} ${time} write --no-cleanup
#for p in $(seq $parallel); do
#  sudo bin/rados bench -p mybench -b ${bs} -o ${os} -t ${qdepth} --run-name=${run_name}_${p} ${time} write --no-cleanup &
#done
sudo bin/rados bench -p mybench -b ${bs} -o ${os} -t ${qdepth} --run-name=${run_name}_${p} ${time} write --no-cleanup > rados_bench_${qdepth}.txt
wait
do_dump 1 > dump_${qdepth}.txt
echo rados bench finished
