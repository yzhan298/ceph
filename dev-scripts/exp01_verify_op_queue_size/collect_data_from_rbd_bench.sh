#!/bin/bash
set -ex

skip_first_60s=65 # skip first 60s of data(1 data per second), skip the first 5 lines in the rbd bench result
file_rbd_bench=./dump-rbd-bench
DATA_OUT_FILE=dump-rbd-bench.csv
printf '%s\n' 'IOPs' 'Throughput' | paste -sd ',' > ${DATA_OUT_FILE}
awk 'NR >= 65 {print $3, ($4/1048576)}' $file_rbd_bench | head -n-3 | grep "\S" | tr ' ' ','  >> ${DATA_OUT_FILE}
