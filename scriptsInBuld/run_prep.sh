#!/bin/bash

# start 1 OSD ceph cluster
OSD=1 MON=1 MDS=0 MGR=0 ../src/vstart.sh -n -x -d -b

# create bench pool
bin/ceph osd pool create mybench 100 100
