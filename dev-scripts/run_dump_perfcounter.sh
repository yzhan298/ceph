#!/bin/bash

sudo ../src/stop.sh
sudo OSD=1 MON=1 MDS=0 MGR=0 ../src/vstart.sh -n -x -d -b
sudo bin/ceph osd pool create mybench 150 150
sleep 5
sudo bin/rados put obj01 a_4k_file -p mybench
sudo bin/ceph daemon osd.0 perf dump osd > perf.txt
sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
