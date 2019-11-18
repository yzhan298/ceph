#!/bin/bash

# colleting kv_queue size

DATA_OUT_FILE=dump-kvq-size.csv
#printf '%s\n' 'kvq_size' 'used CPU (%)' 'total memory (KB)' 'used memory (KB)' 'free memory (KB)' | paste -sd ',' > ${DATA_OUT_FILE}
#awk '{print $6}' out/osd.0.log | grep kv_queue_size | grep "\S" | grep -Eo '[0-9]'  > ${DATA_OUT_FILE}
awk '{print $6}' out/osd.0.log | grep kv_queue_size | sed 's/[^0-9]*//g' | tr ' ' ',' > ${DATA_OUT_FILE}

