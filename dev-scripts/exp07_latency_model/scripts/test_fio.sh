#!/bin/bash

bs="4096" #"131072"  # block size or object size (Bytes)
rw="write"  # io type randwrite, write
fioruntime=10  # seconds
qd=48

#sudo bin/ceph osd pool delete mybench mybench --yes-i-really-really-mean-it
./start_ceph.sh
        sudo bin/ceph osd pool create mybench 128 128
        sudo bin/rbd create --size=40G mybench/image1
        #sleep 15 # warmup
        sed -i "s/iodepth=.*/iodepth=${qd}/g" fio_write.fio
        sed -i "s/bs=.*/bs=${bs}/g" fio_write.fio
        sed -i "s/rw=.*/rw=${rw}/g" fio_write.fio
        sed -i "s/runtime=.*/runtime=${fioruntime}/g" fio_write.fio
        #sed -i "s/size=.*/size=${iototal}/g" fio_write.fio
sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio fio_write.fio
sudo bin/ceph daemon osd.0 perf dump > temp_perf_dump_${rw}_${bs}_${qd}
./clean_rbd.sh
