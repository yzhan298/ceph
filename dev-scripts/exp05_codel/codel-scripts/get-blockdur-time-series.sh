#!/bin/bash
sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -d -k -x -l --without-dashboard
sudo bin/ceph osd pool create mybench 128 128
sudo bin/rados bench -p mybench -b 4096 -o 4096 -t 128 60 write --no-cleanup
awk '{print $5}' out/osd.0.log | grep current_blocking_dur | grep -Eo '[+-]?[0-9]+([.][0-9]+)?' | tr ' ' ',' > block_dur.csv
./stop.sh
python plot_codel.py
