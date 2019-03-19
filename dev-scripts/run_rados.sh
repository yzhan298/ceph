#!/bin/bash

bs=4194304  #4096 #131072
os=4194304  #4096
qdepth=128
time=30
parallel=1

run_name=t_test
osd_count=1
shard_count=2
temp=/tmp/load-ceph.$$

sudo ../src/stop.sh
sudo OSD=1 MON=1 MDS=0 MGR=1 ../src/vstart.sh -n -x -d -b
sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
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
    sudo bin/ceph daemon osd.0 perf reset osd >/dev/null 2>/dev/null
    lat=$(jq ".osd.op_latency.avgtime" $dump_osd)
    wlat=$(jq ".osd.op_w_latency.avgtime" $dump_osd)
    echo "${count}.${o}#osd_op_latency : ${lat}"
    echo "${count}.${o}#osd_op_w_latency : ${wlat}"
    
    dump_bluestore="dump.bs.${count}"
    #sudo bin/ceph daemon osd.0 perf dump bluestore commit_lat 2>/dev/null | tee $dump_bluestore
    sudo bin/ceph daemon osd.0 perf dump bluestore 2>/dev/null | tee $dump_bluestore
    sudo bin/ceph daemon osd.0 perf reset bluestore >/dev/null 2>/dev/null
    lat=$(jq ".bluestore.commit_lat.avgtime" $dump_bluestore)
    echo "${count}.${o}#bluestore_commit_lat : ${lat}"
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

samples=$(expr $time / 2 - 3 | bc -l)
time_dump $samples 5 > dump.result &

#rados bench
#sudo echo 3 | sudo tee /proc/sys/vm/drop_caches && sudo sync
#sudo CEPH_ARGS="--log-file log_radosbench --debug-ms 1" bin/rados bench -p mybench -c ceph.conf -b ${bs} -o ${os} -t ${qdepth} ${time} write --no-cleanup
for p in $(seq $parallel); do
  sudo bin/rados bench -p mybench -b ${bs} -o ${os} -t ${qdepth} --run-name=${run_name}_${p} ${time} write --no-cleanup &
done
#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
wait
echo rados bench finished
