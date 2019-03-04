#!/bin/bash

bs=8m #128k
qdepth=1
time=5
iotype=write

sudo ../src/stop.sh
sudo OSD=1 MON=1 MDS=0 MGR=1 ../src/vstart.sh -n -X -d -b
#sudo ../src/vstart.sh -k -x -d -b

#create a pool
sudo bin/ceph osd pool create rbd 150 150
sudo bin/ceph osd crush tunables hammer
sudo bin/rbd create vol1 --size 20G --image-feature layering
sudo bin/rbd map vol1 --name client.admin
sudo mkfs.xfs /dev/rbd/rbd/vol1
sudo mkdir /mnt/vol1-block-device
sudo mount /dev/rbd/rbd/vol1 /mnt/vol1-block-device

sleep 5
#fio
sudo echo 3 | sudo tee /proc/sys/vm/drop_caches && sudo sync
sudo fio --ioengine=rbd --clientname=admin --pool=rbd --rbdname=vol1 --rw=${iotype} --bs=${bs} --runtime=${time} --name=fio_test --iodepth=${qdepth} --time_based=1 --direct=1
#sudo bin/ceph osd pool delete rados rados --yes-i-really-really-mean-it
#./clean_fio_rbd.sh
