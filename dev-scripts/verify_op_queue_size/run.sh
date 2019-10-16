#!/bin/bash

sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
sudo ../src/stop.sh
# for new ceph.conf
#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -n -x -l --without-dashboard
# for existing ceph.conf
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -k -x -l --without-dashboard

# create pool
sudo bin/ceph osd pool create mybench 150 150

# run rados bench 
./sampling_perf_state.sh 1

# plot with python
echo "backend: Agg" > ~/.config/matplotlib/matplotlibrc
python plot.py
