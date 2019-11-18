#!/bin/bash

# running rbd bench 
RBD_IMAGE_NAME="bench1"
iotype="write"
iosize="128K"
iothread=$1
iototal=$2
iopattern="rand"

sudo bin/rbd rm rbdbench/$RBD_IMAGE_NAME
sudo bin/ceph osd pool delete rbdbench rbdbench --yes-i-really-really-mean-it
sudo ../src/stop.sh
# for new ceph.conf
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -n -x -l --without-dashboard
# for existing ceph.conf
#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -k -x -l --without-dashboard

# create pool
sudo bin/ceph osd pool create rbdbench 150 150

# create rbd image
sudo bin/rbd create --size=10G rbdbench/$RBD_IMAGE_NAME

# run rbd bench
sudo bin/rbd -p rbdbench bench $RBD_IMAGE_NAME --io-type $iotype --io-size $iosize --io-threads $iothread --io-total $iototal --io-pattern $iopattern 2>&1 | tee  dump-rbd-bench
# rbd cache = false/true may bring huge difference

