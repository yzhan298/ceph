#!/bin/bash
sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
sudo ../src/stop.sh
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -n -x -l -b

#create a pool
sudo bin/ceph osd pool create mybench 150 150
#for qdepth in {1..9..1}
#do
#  ./run_rados_single_dump.sh $qdepth
#done

#for qdepth in {10..400..10}
#do
#  ./run_rados_single_dump.sh $qdepth
#done

for qdepth in {1..10..1}
do
  ./run_rados_single_dump.sh $qdepth
done

