#!/bin/bash

#for qdepth in {1..9..1}
#do
#  ./run_rados_single_dump.sh $qdepth
#done

#for qdepth in {10..400..10}
#do
#  ./run_rados_single_dump.sh $qdepth
#done

for qdepth in {400..1000..10}
do
  ./run_rados_single_dump.sh $qdepth
done
