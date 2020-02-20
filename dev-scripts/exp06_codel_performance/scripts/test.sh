#!/bin/bash

#declare -a list1=("4k" "8k" "16k")
#declare -a list2=("400m" "1g" "2g")

#while [ "${#list1[@]}" -gt 0 ] && [ "${#list2[@]}" -gt 0 ]; do
#	echo ${#list1[@]}
#	echo "${#list2[@]}"
#done

INPUT=./kvq_lat_analysis_vec.csv
#while read kvq_p99_lat kvq_p95_lat kvq_median_lat kvq_min_lat kv_sync_p99_lat kv_sync_p95_lat kv_sync_median_lat kv_sync_min_lat
#do
#	echo "kvq_p99_lat : $kvq_p99_lat"
#	echo "kvq_p95_lat : $kvq_p95_lat"
#	echo "kvq_median_lat : $kvq_median_lat"
#	echo "kvq_min_lat : $kvq_min_lat"
#	echo "kv_sync_p99_lat : $kv_sync_p99_lat"
#	echo "kv_sync_p95_lat : $kv_sync_p95_lat"
#	echo "kv_sync_median_lat : $kv_sync_median_lat"
#	echo "kv_sync_min_lat : $kv_sync_min_lat"
#done < $INPUT

variable1=$(awk 'BEGIN { FS = "," } ; NR == 2{ print $1 }' < kvq_lat_analysis_vec.csv)
echo $variable1

