#!/bin/bash

#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
#sudo ../src/stop.sh

#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -k -x -l --without-dashboard
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -n -x -l --without-dashboard
#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -n -b --without-dashboard
#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -k -b --without-dashboard
sudo bin/ceph osd pool create mybench 128 128
