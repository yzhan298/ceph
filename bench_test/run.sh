#!/bin/bash

cd ../build
../bench_test/my-new-vstart
../src/stop.sh

options="NO OLD NEW"
for o in $options
do
  cp ../build/ceph.conf ../build/ceph.conf.${o}
done

sed -i -e 's/osd throttle = 1/osd throttle = 0/g' ../build/ceph.conf.NO
sed -i -e 's/osd throttle = 1/osd throttle = 2/g' ../build/ceph.conf.NEW

../bench_test/load-ceph-many.sh

cp ../bench_test/make-julia6.sh .
cp ../bench_test/load-all.jl .
#./make-julia6.sh
#julia load-all.jl
../bench_test/draw.sh
