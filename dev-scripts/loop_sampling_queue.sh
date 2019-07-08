#!/bin/bash
sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
sudo ../src/stop.sh
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -n -x -l -b

#create a pool
sudo bin/ceph osd pool create mybench 150 150

for qdepth in {100..1000..100}
do
  ./sampling_rados_single.sh $qdepth
done
