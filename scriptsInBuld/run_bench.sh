#!/bin/bash
set -ex

# run benchmark 5 times
for i in `seq 1 5`
do
  echo "bench mark: $i"
  bin/rados bench -p mybench -c ceph.conf -b 4096 -o 4096 60 write >> bench_result.txt
done
