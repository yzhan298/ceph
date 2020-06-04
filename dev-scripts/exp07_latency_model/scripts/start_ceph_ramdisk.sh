#!/bin/bash

sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -n -b -x -l  -o 'bluestore fsck on mkfs = false' -o 'bluestore fsck on mount = false' -o 'bluestore fsck on umount = false' -o 'bluestore block db path = ' -o 'bluestore block wal path = ' -o 'bluestore block wal create = false' -o 'bluestore block db create = false' -o 'bluestore block create = true' -o 'bluestore block size = 32G' --without-dashboard
