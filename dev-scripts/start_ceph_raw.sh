#!/bin/bash
#set -ex

DEVICE=/dev/sdc

sudo ../src/stop.sh

# use raw device with vstart
# learnt from Sage, in this example, the raw device is /dev/sdc
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -d -n -x -l -o 'bluestore block = $(DEVICE)' -o 'bluestore block path = $(DEVICE)' -o 'bluestore fsck on mkfs = false' -o 'bluestore fsck on mount = false' -o 'bluestore fsck on umount = false' -o 'bluestore block db path = ' -o 'bluestore block wal path = ' -o 'bluestore block wal create = false' -o 'bluestore block db create = false'

#create a pool
#sudo bin/ceph osd pool create rados 150 150
sudo bin/ceph osd pool create mybench 150 150
