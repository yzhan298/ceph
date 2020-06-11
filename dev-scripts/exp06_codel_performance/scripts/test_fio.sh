#!/bin/bash

#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it

./start_ceph.sh
sudo bin/ceph osd pool create mybench 128 128
sudo bin/rbd create --size=10G mybench/image1
sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio fio_write.fio