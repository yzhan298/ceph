#!/bin/bash

bs=131072
qdepth=512
time=30

#format drive
#sudo mkfs.xfs -f /dev/sdb1
sudo ../src/stop.sh
#mount osd to the drive
#sudo mount -t xfs /dev/sdb1 ~/ceph/build/dev/osd0/
#sudo OSD=1 MON=1 MDS=0 MGR=0 ../src/vstart.sh -n -x -d -b
sudo ../src/vstart.sh -k -x -d -b

#create a pool
sudo bin/ceph osd pool create rbdbench 150 150
#sudo bin/ceph osd pool create mybench 150 150

#create image
#sudo bin/ceph auth get-or-create client.admin mon 'allow r' osd 'allow * pool=rbdbench' -o adminkeyring
sudo bin/rbd feature disable rbdbench/image01 object-map fast-diff deep-flatten
sudo bin/rbd create image01 --size 1024 --pool rbdbench --image-feature layering
sudo bin/rbd map image01 --pool rbdbench --name client.admin #-k adminkeyring
sudo mkfs.xfs /dev/rbd/rbdbench/image01
sudo mkdir /mnt/ceph-block-device
sudo mount /dev/rbd/rbdbench/image01 /mnt/ceph-block-device  

sleep 10
#rados bench 
#sudo bin/rados bench -p mybench -c ceph.conf -b ${bs} -o ${os} -t ${qdepth} ${time} write --no-cleanup
#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it

#fio
#sudo fio fio_benchmark.fio 
#sudo CEPH_ARGS="--log-file log_fio --debug-ms 1"  fio --ioengine=rados --clientname=admin --pool=rados --rw=write --bs=128k --runtime=3 --name=fio_test --iodepth=32 --size=200G 
sudo fio --ioengine=rbd --clientname=admin --pool=rbdbench --rw=write --bs=${bs} --runtime=${time} --name=fio_test --iodepth=${qdepth}
sudo bin/rbd rm rbdbench/image01
sudo umount /mnt/ceph-block-device
sudo rm -rf /mnt/ceph-block-device
sudo bin/ceph osd pool delete rbdbench rbdbench --yes-i-really-really-mean-it

