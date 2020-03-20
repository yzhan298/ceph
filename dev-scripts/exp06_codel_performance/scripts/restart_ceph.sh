#!/bin/bash

sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -k -o 'bluestore block = /dev/sdc' -o 'bluestore block path = /dev/sdc' -o 'bluestore fsck on mkfs = false' -o 'bluestore fsck on mount = false' -o 'bluestore fsck on umount = false' -o 'bluestore block db path = ' -o 'bluestore block wal path = ' -o 'bluestore block wal create = false' -o 'bluestore block db create = false' --without-dashboard
#sudo bin/ceph osd pool create mybench 128 128
