#!/bin/bash

#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
#sudo ../src/stop.sh

#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -k -x -l --without-dashboard
#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -n -x -l --without-dashboard
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -n -b --without-dashboard
#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -k -b --without-dashboard #-m 128.114.52.120:40510
sudo bin/ceph osd pool create mybench 128 128
