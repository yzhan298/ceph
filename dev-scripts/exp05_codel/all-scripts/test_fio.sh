#!/bin/bash

bs=4096
qdepth=1
iotype="write"
iototal="10M"
iopattern="rand"

#sudo bin/rbd rm mybench/bench1
#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
#sudo ../src/stop.sh

sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -k -x  --without-dashboard
sudo bin/ceph osd pool create mybench 128 128
sudo bin/rbd create --size=10G mybench/bench1

sudo fio fio_write.fio #> dump-fio-bench
