#!/bin/bash

bs=128k #128k
qdepth=4096
time=60
size=100G
iotype=write
#thread=2

#format drive
#sudo mkfs.xfs -f /dev/sdb1
sudo ../src/stop.sh
#mount osd to the drive
#sudo mount -t xfs /dev/sdb1 ~/ceph/build/dev/osd0/
sudo OSD=1 MON=1 MDS=0 MGR=0 ../src/vstart.sh -n -x -d -b
#sudo ../src/vstart.sh -k -x -d -b

#create a pool
sudo bin/ceph osd pool create rados 150 150
#sudo bin/ceph osd pool create mybench 150 150

sleep 10
#rados bench
#sudo bin/rados bench -p mybench -c ceph.conf -b ${bs} -o ${os} -t ${qdepth} ${time} write --no-cleanup
#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it

#fio
#sudo fio fio_benchmark.fio
#sudo CEPH_ARGS="--log-file log_fio --debug-ms 1"  fio --ioengine=rados --clientname=admin --pool=rados --rw=write --bs=128k --runtime=3 --name=fio_test --iodepth=32 --size=200G
#sudo echo 3 | sudo tee /proc/sys/vm/drop_caches && sudo sync
#sudo fio --ioengine=rados --clientname=admin --pool=rados --rw=write --bs=${bs} --runtime=${time} --name=fio_test --iodepth=${qdepth} --size=${size} --busy_poll=0 --write_iolog=fio_iolog --thread=${thread}
sudo fio --ioengine=rados --clientname=admin --pool=rados --rw=${iotype} --bs=${bs} --runtime=${time} --name=fio_test --iodepth=${qdepth} --size=${size} --write_iolog=fio_iolog --time_based=1
sudo bin/ceph osd pool delete rados rados --yes-i-really-really-mean-it
