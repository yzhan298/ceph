#!/bin/bash
set -ex

bs=4096 #4k: 4096 #128k: 131072 #4m: 4194304
os=4096 #4194304  #4096
qdepth=$1
time=300 #5mins=300
parallel=1
sampling_time=6 # second(s)

run_name=t_test_${qdepth}
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
sudo bin/ceph daemon osd.0 perf reset osd >/dev/null 2>/dev/null
