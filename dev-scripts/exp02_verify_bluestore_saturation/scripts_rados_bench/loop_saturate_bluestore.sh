#!/bin/bash

#for qdepth in {10..400..10}
DATA_OUT_FILE="dump-result.csv"

#printf '%s\n' "bs" "runtime" "concurrency" "throughput" "latency" |  paste -sd ',' > ${DATA_OUT_FILE}

#for qdepth in 1 8 16 24 32 40 48 56 64 72 80 88 96 104 112 120 128; do
for qdepth in {136..512..8}
do
	  ./run_saturate_bluestore.sh $qdepth
  done
