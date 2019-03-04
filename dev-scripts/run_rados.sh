#!/bin/bash

bs=4194304 #131072
os=4194304
qdepth=16
time=10

#format drive
#sudo mkfs.xfs -f /dev/sdb1
sudo ../src/stop.sh
#mount osd to the drive
#sudo mount -t xfs /dev/sdb1 ~/ceph/build/dev/osd0/
sudo OSD=1 MON=1 MDS=0 MGR=0 ../src/vstart.sh -n -x -d -b
#sudo ../src/vstart.sh -k -x -d -b

#create a pool
#sudo bin/ceph osd pool create rados 150 150
sudo bin/ceph osd pool create mybench 150 150

sleep 5

#rados bench
# sudo echo 3 | sudo tee /proc/sys/vm/drop_caches && sudo sync
# sudo CEPH_ARGS="--log-file log_radosbench --debug-ms 1" bin/rados bench -p mybench -c ceph.conf -b ${bs} -o ${os} -t ${qdepth} ${time} write --no-cleanup
sudo bin/rados bench -p mybench -b ${bs} -o ${os} -t ${qdepth} ${time} write --no-cleanup
sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it

