#!/bin/bash

iodp=12
#sed -i "s/kv_queue_size=.*/iodepth=${iodp}/g" fio_write.fio
#cat out/osd.0.log | grep kv_queue_size
#awk '{print $5}' out/osd.0.log | grep kv_queue_size | grep "\S"| tr ' ' ',' > test.txt #grep -Eo '[0-9]'
awk '{print $6}' out/osd.0.log | grep kv_queue_size | sed 's/[^0-9]*//g' | tr ' ' ',' > test.txt

# get total memory (KB)
#free | grep Mem | awk '{print $2}'

# get used memory (KB)
#free | grep Mem | awk '{print $3}'

# get free memory (KB)
#free | grep Mem | awk '{print $4}'

# get used CPU (%)
#iostat | awk 'NR == 4 {print $1}'


