#!/bin/bash

bs=4096
qdepth=1
iotype="write"
iototal="10M"
iopattern="rand"

#sudo bin/rbd rm mybench/bench1
#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
#sudo ../src/stop.sh

#sudo MON=1 OSD=1 MDS=0 MGR=1 ../src/vstart.sh -k
#sudo bin/ceph osd pool create mybench 128 128
./start_ceph.sh
sudo bin/rbd create --size=1G mybench/image1

sudo fio fio_write.fio #> dump-fio-bench
