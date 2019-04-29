#!/bin/bash

#set -ex

bs=4096 #4k: 4096 #128k: 131072 #4m: 4194304
os=4096 #4194304  #4096
qdepth=200
time=30
parallel=1

run_name=t_test
osd_count=1
shard_count=2
temp=/tmp/load-ceph.$$

CURRENTDATE=`date +"%Y-%m-%d %T"`
#DATA_OUT_FILE="res_${qdepth}_${time}.csv"
DATA_OUT_FILE="result.csv"

sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
sudo ../src/stop.sh
#sudo OSD=1 MON=1 MDS=0 MGR=1 ../src/vstart.sh -n -x -d -b
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -d -n -x -l -b
#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
#sudo ../src/vstart.sh -k -x -d -b

#create a pool
sudo bin/ceph osd pool create mybench 150 150


do_dump() {
  count=$1
  #dump sharded op queue size
  for o in $(seq 0 $(expr $osd_count - 1)) ; do
    dump_opq="dump.op_queue.${count}"
    sudo bin/ceph daemon osd.0 dump_op_pq_state 2>/dev/null | tee $dump_opq
    #sudo bin/ceph daemon osd.0 dump_op_pq_state 2>/dev/null | tee $dump_opq | jq 'map(.size)' >$temp
    #for  s in $(seq 0 $(expr $shard_count - 1)) ; do
    #  size=$(jq ".[${s}]" $temp)
    #  echo "${count}.${o}.${s} : ${size}"
    #done
    
    dump_osd="dump.osd.${count}"
    sudo bin/ceph daemon osd.0 perf dump osd 2>/dev/null | tee $dump_osd
    #sudo bin/ceph daemon osd.0 perf reset osd >/dev/null 2>/dev/null
    op_lat=$(jq ".osd.op_latency.avgtime" $dump_osd) # client io latency
    op_bw=$(jq ".osd.op_in_bytes" $dump_osd) # client io throughput 
    op_throughput=$(expr $op_bw/1048576/$time | bc -l) # client io throughput
    #echo "#op_latency : $op_lat, op_throughput=$(expr $op_bw/1048576/$time | bc -l)"

    
    dump_bluestore="dump.bs.${count}"
    #sudo bin/ceph daemon osd.0 perf dump bluestore commit_lat 2>/dev/null | tee $dump_bluestore
    sudo bin/ceph daemon osd.0 perf dump bluestore 2>/dev/null | tee $dump_bluestore
    #sudo bin/ceph daemon osd.0 perf reset bluestore >/dev/null 2>/dev/null
    kv_flush_lat=$(jq ".bluestore.kv_flush_lat.avgtime" $dump_bluestore)
    kv_commit_lat=$(jq ".bluestore.kv_commit_lat.avgtime" $dump_bluestore)
    kv_lat=$(jq ".bluestore.kv_lat.avgtime" $dump_bluestore)
    state_prepare_lat=$(jq ".bluestore.state_prepare_lat.avgtime" $dump_bluestore)
    state_aio_wait_lat=$(jq ".bluestore.state_aio_wait_lat.avgtime" $dump_bluestore)
    state_io_done_lat=$(jq ".bluestore.state_io_done_lat.avgtime" $dump_bluestore)
    #echo "#bluestore_kv_lat : ${kv_lat}"
  done  
  #printf "%s\n" ${CURRENTDATE} |  paste -sd ',' >> ${DATA_OUT_FILE}
  #printf '%s\n' "bs" "runtime" "client_qd" "op_thput" "op_lat" "kv_flush_lat" "kv_commit_lat" "kv_lat" "state_prepare_lat" "aio_wait_lat" "io_done_lat" |  paste -sd ',' >> ${DATA_OUT_FILE}
  printf '%s\n' $bs $time $qdepth $op_throughput $op_lat $kv_flush_lat $kv_commit_lat $kv_lat $state_prepare_lat $state_aio_wait_lat $state_io_done_lat | paste -sd ',' >> ${DATA_OUT_FILE}
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

samples=$(expr $time / 5 | bc -l)
#time_dump $samples 5 > dump.result &

#rados bench
#sudo echo 3 | sudo tee /proc/sys/vm/drop_caches && sudo sync
#sudo CEPH_ARGS="--log-file log_radosbench --debug-ms 1" bin/rados bench -p mybench -c ceph.conf -b ${bs} -o ${os} -t ${qdepth} ${time} write --no-cleanup
for p in $(seq $parallel); do
  sudo bin/rados bench -p mybench -b ${bs} -o ${os} -t ${qdepth} --run-name=${run_name}_${p} ${time} write --no-cleanup &
done
#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
wait
do_dump 1 > dump.txt
echo rados bench finished
