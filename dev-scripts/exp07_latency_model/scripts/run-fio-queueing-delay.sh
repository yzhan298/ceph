#!/bin/bash
#sudo ../src/stop.sh
#sudo bin/init-ceph stop
#sleep 5

# run rbd bench and collect result
bs="4096"   #"131072"  # block size or object size (Bytes)
rw="randwrite"  # io type
fioruntime=10  # seconds
iototal="400m" # total bytes of io
#qd=48 # workload queue depth

# no need to change
osd_count=1            	 	# number of OSDs
shard_count=1           	# number of sharded op_queue
DATA_FILE=dump-lat-analysis.csv  # output file name
pool="mybench"

single_dump() {
    qdepth=$1
    for o in $(seq 0 $(expr $osd_count - 1)) ; do
        dump_state="dump-state-${qdepth}"
        sudo bin/ceph daemon osd.0 perf dump 2>/dev/null > $dump_state
	#avg_throughput_bench=$(grep "Bandwidth (MB/sec)" dump-rados-bench-${qdepth}) #| awk '{print $3}')
	#bw=$(grep BW dump-fio-bench-${qdepth} |  awk '{print $3}') # | grep -o '[0-9]*')
	clt_bw=$(echo "$(jq '.jobs[0].write.bw' dump-fio-bench-${qdepth}.json) / 1024" | bc -l) #client throughput MB/s
	clt_lat=$(echo "$(jq '.jobs[0].write.lat_ns.mean' dump-fio-bench-${qdepth}.json) / 1000000000" | bc -l) # client latency seconds
	osd_op_in_osd_lat=$(jq ".osd.osd_op_in_osd_lat.avgtime" $dump_state)
	osd_op_queueing_time=$(jq ".osd.osd_op_queueing_time.avgtime" $dump_state)
	bluestore_simple_writes_lat=$(jq ".bluestore.bluestore_simple_writes_lat.avgtime" $dump_state) # simple write latency
	bluestore_deferred_writes_lat=$(jq ".bluestore.bluestore_deferred_writes_lat.avgtime" $dump_state) # deferred write latency
	bluestore_kv_queue_time=$(jq ".bluestore.bluestore_kv_queue_time.avgtime" $dump_state)
	bluestore_kv_sync_lat=$(jq ".bluestore.kv_sync_lat.avgtime" $dump_state) # flush + commit
	bluestore_kvq_lat=$(jq ".bluestore.bluestore_kvq_lat.avgtime" $dump_state) # queueing lat + flush/commit
	bluestore_simple_service_lat=$(jq ".bluestore.bluestore_aio_lat.avgtime" $dump_state)
	bluestore_deferred_service_lat=$(jq ".bluestore.bluestore_dio_lat.avgtime" $dump_state)
    
    printf '%s\n' $bs $fioruntime $qd $clt_bw $clt_lat $osd_op_in_osd_lat $osd_op_queueing_time $bluestore_simple_writes_lat $bluestore_deferred_writes_lat $bluestore_kv_queue_time $bluestore_kv_sync_lat $bluestore_kvq_lat $bluestore_simple_service_lat $bluestore_deferred_service_lat | paste -sd ',' >> ${DATA_FILE} 
    done
    #sudo bin/ceph daemon osd.0 perf reset osd
}

#for j in 1 2 3 4 5; do
printf '%s\n' "bs" "runtime" "qdepth" "bw_mbs" "lat_s" "osd_lat" "op_queue_lat" "bluestore_simple_writes_lat" "bluestore_deferred_writes_lat" "kv_queue_lat" "bluestore_kv_sync_lat" "bluestore_kvq_lat" "bluestore_simple_service_lat" "bluestore_deferred_service_lat" |  paste -sd ',' > ${DATA_FILE} 
#"kv_sync_p99_lat" "kv_sync_p95_lat" "kv_sync_median_lat" "kv_sync_min_lat" "kvq_p99_lat" "kvq_p95_lat" "kvq_median_lat" "kvq_min_lat" |  paste -sd ',' > ${DATA_FILE}
#for qd in {16..72..8}; do
for qd in 48; do
	#bs="$((2**i*4*1024))"
	#iototal="$((2**i*4*1024*100000))"   #"$((2**i*40))m"
	./start_ceph.sh
	sudo bin/ceph osd pool create mybench 128 128
	sudo bin/rbd create --size=40G mybench/image1
	sleep 10 # warmup
	sed -i "s/iodepth=.*/iodepth=${qd}/g" fio_write.fio
	sed -i "s/bs=.*/bs=${bs}/g" fio_write.fio
	sed -i "s/rw=.*/rw=${rw}/g" fio_write.fio
	sed -i "s/runtime=.*/runtime=${fioruntime}/g" fio_write.fio
	#sed -i "s/size=.*/size=${iototal}/g" fio_write.fio
        
    echo benchmark starts!
	echo $qd
    sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio fio_write.fio --output-format=json | tee fio-bench-${qd}.json #--output=dump-fio-bench-${qd}.json 
	sleep 5
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
	#mv ./blocking_dur_vec.csv ./dump_blocking_dur_vec-${qd}.csv
        # it contains kvq_p99_lat, kvq_p95_lat, kvq_median_lat, kvq_min_lat, kv_sync_p99_lat, kv_sync_p95_lat, kv_sync_median_lat, kv_sync_min_lat
        # process kvq_lat.csv and kv_cync_lat.csv
	#INPUTCSV=dump_kvq_lat_analysis_vec-${qd}.csv
        #kvq_p99_lat=$(awk 'BEGIN { FS = "," } ; NR == 2{ print $1 }' < $INPUTCSV)	


	sudo bin/ceph daemon osd.0 dump opq vector
	mv ./opq_vec.csv ./dump_opq_size_vec-${qd}.csv
	#mv ./opq_lat_vec.csv ./dump_opq_lat_vec-${qd}.csv


	single_dump $qd
        echo benchmark stops!

        #export PLOTOUTNAME="dump-block-dur-${qd}.png"
        #export PLOTINNAME="dump-block-dur-${qd}.csv"
        #python plot_codel.py 
	sudo bin/rbd rm mybench/image1
        sudo bin/ceph osd pool delete $pool $pool --yes-i-really-really-mean-it
        sudo ../src/stop.sh
	#sudo bin/init-ceph --verbose stop
	#sudo bin/init-ceph stop
	#sleep 5
	#sudo rm -rf dev out
	#sudo rm -rf ceph.conf
done

#python plot-codel.py

# move everything to a directory
dn=queueing-delay-${rw}-$(date +"%Y_%m_%d_%I_%M_%p")
sudo mkdir -p ${dn} # create data if not created
sudo mv dump* ${dn}
sudo cp ceph.conf ${dn}
sudo mv ${dn} ./data
echo DONE!
#done
