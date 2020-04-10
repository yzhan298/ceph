#!/bin/bash

bs="4096" #"131072"  # block size or object size (Bytes)
rw="write"  # io type randwrite, write
fioruntime=60  # seconds
qd=48

PERFFILE=dump_perf_${rw}_${bs}_${qd}
DATA_FILE=dump-lat-analysis.csv 

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
sudo bin/ceph daemon osd.0 perf dump > ${PERFFILE}

printf '%s\n' "bs" "runtime" "qdepth" "bw_MBs" "lat_s" "osd_lat" "op_queue_lat" "bluestore_simple_writes_lat" "bluestore_deferred_writes_lat" "kv_queue_lat" "bluestore_kv_sync_lat" "bluestore_kvq_lat" "bluestore_simple_service_lat" "bluestore_deferred_service_lat" |  paste -sd ',' > ${DATA_FILE} 
#clt_bw=$(echo "$(jq '.jobs[0].write.bw' dump-fio-bench-${qd}.json) / 1024" | bc -l) #client throughput MB/s
#clt_lat=$(echo "$(jq '.jobs[0].write.lat_ns.mean' dump-fio-bench-${qd}.json) / 1000000000" | bc -l) # client latency seconds
clt_bw=0 # placeholder
clt_lat=0 # placeholder
osd_op_in_osd_lat=$(jq ".osd.osd_op_in_osd_lat.avgtime" $PERFFILE)
osd_op_queueing_time=$(jq ".osd.osd_op_queueing_time.avgtime" $PERFFILE)
bluestore_simple_writes_lat=$(jq ".bluestore.bluestore_simple_writes_lat.avgtime" $PERFFILE) # simple write latency
bluestore_deferred_writes_lat=$(jq ".bluestore.bluestore_deferred_writes_lat.avgtime" $PERFFILE) # deferred write latency
bluestore_kv_queue_time=$(jq ".bluestore.bluestore_kv_queue_time.avgtime" $PERFFILE)
bluestore_kv_sync_lat=$(jq ".bluestore.kv_sync_lat.avgtime" $PERFFILE) # flush + commit
bluestore_kvq_lat=$(jq ".bluestore.bluestore_kvq_lat.avgtime" $PERFFILE) # queueing lat + flush/commit
bluestore_simple_service_lat=$(jq ".bluestore.bluestore_aio_lat.avgtime" $PERFFILE)
bluestore_deferred_service_lat=$(jq ".bluestore.bluestore_dio_lat.avgtime" $PERFFILE)
printf '%s\n' $bs $fioruntime $qd $clt_bw $clt_lat $osd_op_in_osd_lat $osd_op_queueing_time $bluestore_simple_writes_lat $bluestore_deferred_writes_lat $bluestore_kv_queue_time $bluestore_kv_sync_lat $bluestore_kvq_lat $bluestore_simple_service_lat $bluestore_deferred_service_lat | paste -sd ',' >> ${DATA_FILE} 

sudo bin/ceph daemon osd.0 dump kvq vector
	mv ./kvq_lat_vec.csv ./dump_kvq_lat_vec-${qd}.csv
	mv ./kv_sync_lat_vec.csv ./dump_kv_sync_lat_vec-${qd}.csv
	mv ./txc_bytes_vec.csv ./dump_txc_bytes_vec-${qd}.csv
	mv ./bluestore_lat_vec.csv ./dump_bluestore_lat_vec-${qd}.csv
	mv ./bluestore_simple_writes_lat_vec.csv ./dump_bluestore_simple_writes_lat_vec-${qd}.csv
	mv ./bluestore_deferred_writes_lat_vec.csv ./dump_bluestore_deferred_writes_lat_vec-${qd}.csv
	mv ./bluestore_simple_service_lat_vec.csv ./dump_bluestore_simple_service_lat_vec-${qd}.csv
	mv ./bluestore_deferred_service_lat_vec.csv ./dump_bluestore_deferred_service_lat_vec-${qd}.csv
	mv ./kv_queue_size_vec.csv ./dump_kv_queue_size_vec-${qd}.csv

sudo bin/ceph daemon osd.0 dump opq vector
	mv ./opq_vec.csv ./dump_opq_size_vec-${qd}.csv

./clean_rbd.sh
