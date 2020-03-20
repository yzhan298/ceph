#!/bin/bash

#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it

./start_ceph.sh
sudo bin/ceph osd pool create mybench 128 128
sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio fio_write.fio
sudo bin/rados bench -p mybench -b 4096 -t 32 10 write

sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
sudo ../src/stop.sh
