#!/bin/bash

for qdepth in {410..1000..10}
do
  ./run_rados_single_dump.sh $qdepth
done

#for qdepth in {20..400..10}
#do
#  ./run_rados_single_dump.sh $qdepth
#done
