#!/bin/bash

qdepth=$1 #workload concurrency
benchtool=$2 #accepting "rados" bench, "rbd" bench, "fio" bench
pool="mybench"
rbd_image="bench1"

# for new ceph.conf
#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -n -x -l --without-dashboard
# for existing ceph.conf
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -k -x -l --without-dashboard 

# create pool
sudo bin/ceph osd pool create $pool 128 128

if [ $benchtool = "rbd" ] || [ $benchtool = "fio" ]
then
    sudo bin/rbd create --size=10G ${pool}/${rbd_image}
fi

# run benchmark 
# $1: client queue depth/concurrency
# $2: benchmark tool
./sampling_perf_state.sh ${qdepth} ${benchtool}

# collect rados bench throughput and latency
if [ $benchtool = "rados" ]
then
    ./collect_data_from_rados_bench.sh
fi

# collect kv_queue from osd.log
./collect_kvq_from_log.sh

# plot with python
# run this command for first time:
#echo "backend: Agg" > ~/.config/matplotlib/matplotlibrc
#python plot_sampling.py

# move everything to a directory
dirname=${benchtool}_exp_qd${qdepth}_$(date +"%Y_%m_%d_%I_%M_%p")
mkdir -p data/${dirname} # create data if not created
mv dump* data/${dirname} 

if [ $benchtool = "rbd" ] || [ $benchtool = "fio" ]
then
    sudo bin/rbd rm ${pool}/${rbd_image}
fi
sudo bin/ceph osd pool delete $pool $pool --yes-i-really-really-mean-it
sudo ../src/stop.sh
