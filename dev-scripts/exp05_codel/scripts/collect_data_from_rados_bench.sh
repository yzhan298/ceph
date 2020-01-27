#!/bin/bash
set -ex

skip_first_60s=66 # skip first 60s of data(1 data per second), skip the first 6 lines in the rados bench result
file_rados_bench=./dump-rados*
#avg_throughput_rados_bench=$(grep "Bandwidth (MB/sec)" $file_rados_bench | awk '{print $3}')
#avg_lat_rados_bench=$(grep "Average Latency(s)" $file_rados_bench | awk '{print $3}')
DATA_OUT_FILE=dump-rados-bench.csv
printf '%s\n' 'avg_throughput' 'avg_latency'| paste -sd ',' > ${DATA_OUT_FILE}
awk 'NR >= 66 {print $5, $8}' $file_rados_bench | grep "\S" | grep -vwE "(max|finished)" | tr ' ' ','  >> ${DATA_OUT_FILE}
