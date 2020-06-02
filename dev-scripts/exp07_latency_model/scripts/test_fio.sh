#!/bin/bash

# run rbd bench and collect result
bs="4096"   #"131072"  # block size 
rw="randwrite"  # io type
fioruntime=60  # seconds
iototal="400m" # total bytes of io
qd=48 # workload queue depth

# no need to change
DATA_FILE=dump-lat-analysis.csv  # output file name
pool="mybench"

single_dump() {
    qdepth=$1
    dump_state="dump-state-${qdepth}.json"
    sudo bin/ceph daemon osd.0 dump_op_pq_state 2>/dev/null > dump_op_pq_state
    sudo bin/ceph daemon osd.0 perf dump 2>/dev/null > $dump_state
	osd_op_in_osd_lat=$(jq ".osd.osd_op_in_osd_lat.avgtime" $dump_state)
	osd_op_queueing_time=$(jq ".osd.osd_op_queueing_time.avgtime" $dump_state)
	bluestore_simple_writes_lat=$(jq ".bluestore.bluestore_simple_writes_lat.avgtime" $dump_state) # simple write latency
	bluestore_deferred_writes_lat=$(jq ".bluestore.bluestore_deferred_writes_lat.avgtime" $dump_state) # deferred write latency
	bluestore_kv_queue_time=$(jq ".bluestore.bluestore_kv_queue_time.avgtime" $dump_state)
	bluestore_kv_sync_lat=$(jq ".bluestore.kv_sync_lat.avgtime" $dump_state) # flush + commit
	bluestore_kvq_lat=$(jq ".bluestore.bluestore_kvq_lat.avgtime" $dump_state) # queueing lat + flush/commit
	bluestore_simple_service_lat=$(jq ".bluestore.bluestore_aio_lat.avgtime" $dump_state)
	bluestore_deferred_service_lat=$(jq ".bluestore.bluestore_dio_lat.avgtime" $dump_state)
    bluestore_simple_aio_lat=$(jq ".bluestore.bluestore_simple_async_io_lat.avgtime" $dump_state)
	bluestore_deferred_aio_lat=$(jq ".bluestore.bluestore_deferred_async_io_lat.avgtime" $dump_state)

    printf '%s\n' $bs $fioruntime $qd $osd_op_in_osd_lat $osd_op_queueing_time $bluestore_simple_writes_lat $bluestore_deferred_writes_lat $bluestore_kv_queue_time $bluestore_kv_sync_lat $bluestore_kvq_lat $bluestore_simple_service_lat $bluestore_deferred_service_lat $bluestore_simple_aio_lat $bluestore_deferred_aio_lat | paste -sd ',' >> ${DATA_FILE} 
}
printf '%s\n' "bs" "runtime" "qdepth" "osd_lat" "op_queue_lat" "bluestore_simple_writes_lat" "bluestore_deferred_writes_lat" "kv_queue_lat" "bluestore_kv_sync_lat" "bluestore_kvq_lat" "bluestore_simple_service_lat" "bluestore_deferred_service_lat" "bluestore_simple_aio_lat""bluestore_deferred_aio_lat" |  paste -sd ',' > ${DATA_FILE} 

	#------------- start cluster -------------#
	./start_ceph.sh
	sudo bin/ceph osd pool create mybench 128 128
	sudo bin/rbd create --size=1G mybench/image1 # 4M obj by default

	sleep 5 # warmup

	# change the fio parameters
	sed -i "s/iodepth=.*/iodepth=${qd}/g" fio_write.fio
	sed -i "s/bs=.*/bs=${bs}/g" fio_write.fio
	sed -i "s/rw=.*/rw=${rw}/g" fio_write.fio
	sed -i "s/runtime=.*/runtime=${fioruntime}/g" fio_write.fio
	#sed -i "s/size=.*/size=${iototal}/g" fio_write.fio

	#------------- pre-fill -------------#
	# pre-fill the image(to eliminate the op_rw)
	#echo pre-fill the image!
	#sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio fio_prefill_rbdimage.fio
	# reset the perf-counter
	sudo bin/ceph daemon osd.0 perf reset osd >/dev/null 2>/dev/null
	sudo echo 3 | sudo tee /proc/sys/vm/drop_caches && sudo sync
	# reset admin socket of OSD and BlueStore
	sudo bin/ceph daemon osd.0 reset kvq vector
	sudo bin/ceph daemon osd.0 reset opq vector
	
	#------------- benchmark -------------#
    echo benchmark starts!
	echo $qd
    sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio fio_write.fio #| tee dump_fio_result

	# dump internal data with admin socket
	# BlueStore
	sudo bin/ceph daemon osd.0 dump kvq vector	
	# OSD
	sudo bin/ceph daemon osd.0 dump opq vector
	sudo bin/ceph daemon osd.0 dump_objectstore_kv_stats
	# aggregation
	single_dump $qd
	# rbd info
	sudo bin/rbd info mybench/image1 | tee dump_rbd_info.txt

    echo benchmark stops!

	#------------- stop cluster -------------#
	sudo bin/rbd rm mybench/image1
    sudo bin/ceph osd pool delete $pool $pool --yes-i-really-really-mean-it
    sudo ../src/stop.sh

echo DONE!
#done
