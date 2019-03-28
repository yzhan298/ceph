#!/bin/bash

set -ex

# use raw device with vstart
# learnt from Sage, in this example, the raw device is /dev/sdc
MON=1 OSD=1 MDS=0 ../src/vstart.sh -d -n -x -l -o 'bluestore block = /dev/sdc' -o 'bluestore block path = /dev/sdc' -o 'bluestore fsck on mkfs = false' -o 'bluestore fsck on mount = false' -o 'bluestore fsck on umount = false' -o 'bluestore block db path = ' -o 'bluestore block wal path = ' -o 'bluestore block wal create = false' -o 'bluestore block db create = false'
