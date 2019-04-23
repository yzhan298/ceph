#!/bin/bash
#set -ex

sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
sudo ../src/stop.sh

# use raw device with vstart
# learnt from Sage, in this example, the raw device is /dev/sdc
#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -d -n -x -l -o 'bluestore block = /dev/sdc' -o 'bluestore block path = /dev/sdc' -o 'bluestore fsck on mkfs = false' -o 'bluestore fsck on mount = false' -o 'bluestore fsck on umount = false' -o 'bluestore block db path = ' -o 'bluestore block wal path = ' -o 'bluestore block wal create = false' -o 'bluestore block db create = false'
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -d -n -x -l -b

#create a pool
#sudo bin/ceph osd pool create rados 150 150
sudo bin/ceph osd pool create mybench 150 150
