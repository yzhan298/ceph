#!/bin/bash
set -ex
bt=xx
qdepth=xx

sed -i "s/iodepth=.*/iodepth=${qdepth}/g" testfile

#file_rados_bench=./dump-rados*
#avg_throughput_bench=$(grep "Bandwidth (MB/sec)" $file_rados_bench | awk '{print $3}')

#a=0
#for o in $(seq 0 5); do
#	a=$( echo $a+$o | bc )
#done
#b=$( echo $a/5 | bc )
#echo $b

#dirname=${bt}_plot_qd${qdepth}_$(date +%F)
#mkdir -p data/${dirname}
#mv dump* data/${dirname}
#totaltime=30
#sampling_time=2
#samples=$(expr $totaltime/${sampling_time}-5 | bc -l)
#echo $samples
#iodp=12
#sed -i "s/kv_queue_size=.*/iodepth=${iodp}/g" fio_write.fio
#cat out/osd.0.log | grep kv_queue_size
#awk '{print $5}' out/osd.0.log | grep kv_queue_size | grep "\S"| tr ' ' ',' > test.txt #grep -Eo '[0-9]'
#awk '{print $6}' out/osd.0.log | grep kv_queue_size | sed 's/[^0-9]*//g' | tr ' ' ',' > test.txt

# get total memory (KB)
#free | grep Mem | awk '{print $2}'

# get used memory (KB)
#free | grep Mem | awk '{print $3}'

# get free memory (KB)
#free | grep Mem | awk '{print $4}'

# get used CPU (%)
#iostat | awk 'NR == 4 {print $1}'


