#!/bin/bash

sudo ../src/stop.sh
#mount osd to the drive
#sudo mount -t xfs /dev/sdb1 ~/ceph/build/dev/osd0/
#sudo OSD=1 MON=1 MDS=0 MGR=1 ../src/vstart.sh -n -x -d -b
sudo ../src/vstart.sh -k -x -d -b

#create a pool
sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
#sudo bin/ceph osd pool create rados 150 150
sudo bin/ceph osd pool create mybench 150 150
