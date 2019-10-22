#!/bin/bash

# running rbd bench 
iothread=1
iototal="1G"

# run rbd bench
./rbd_bench.sh ${iothread} ${iototal} 
# collect rbd bench throughput and iops
./collect_data_from_rbd_bench.sh
# plot with python(run this command for first time)
#echo "backend: Agg" > ~/.config/matplotlib/matplotlibrc
python plot_rbd_bench.py

# move everything to a directory
dirname=exp_rbd_t${iothread}_s${iototal}_$(date +%F)
mkdir -p data/${dirname} # create data if not created
mv dump* data/${dirname}
