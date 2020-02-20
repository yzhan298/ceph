#!/bin/bash
#sudo ../src/stop.sh
#sudo bin/init-ceph stop
#sleep 5

# run rbd bench and collect result
bs="4k"  # block size or object size (Bytes)
rw="randwrite"  # io type
fioruntime=30  # seconds
iototal="400m" # total bytes of io
#qd=48 # workload queue depth

# no need to change
osd_count=1            	 	# number of OSDs
shard_count=1           	# number of sharded op_queue
DATA_FILE=dump-queueing-delay.csv  # output file name
pool="mybench"

single_dump() {
    qdepth=$1
    for o in $(seq 0 $(expr $osd_count - 1)) ; do
        dump_state="dump-state-${qdepth}"
        sudo bin/ceph daemon osd.0 perf dump 2>/dev/null > $dump_state
	#avg_throughput_bench=$(grep "Bandwidth (MB/sec)" dump-rados-bench-${qdepth}) #| awk '{print $3}')
	bw=$(grep BW dump-fio-bench-${qdepth} |  awk '{print $3}') # | grep -o '[0-9]*')
        bluestore_kv_sync_lat=$(jq ".bluestore.kv_sync_lat.avgtime" $dump_state)
        bluestore_kvq_lat=$(jq ".bluestore.bluestore_kvq_lat.avgtime" $dump_state)
        printf '%s\n' $bs $iototal $qd $bluestore_kv_sync_lat $bluestore_kvq_lat $kvq_p99_lat $kvq_p95_lat $kvq_median_lat $kvq_min_lat | paste -sd ',' >> ${DATA_FILE}
    done
    #sudo bin/ceph daemon osd.0 perf reset osd
}

#for j in 1 2 3 4 5; do
printf '%s\n' "bs" "iototal" "qdepth" "bluestore_kv_sync_lat" "bluestore_kvq_lat" "kvq_p99_lat" "kvq_p95_lat" "kvq_median_lat" "kvq_min_lat" |  paste -sd ',' > ${DATA_FILE}
for qd in {16..32..16}; do
	#bs="$((2**i*4*1024))"
	#iototal="$((2**i*4*1024*100000))"   #"$((2**i*40))m"
	./start_ceph.sh
	sudo bin/ceph osd pool create mybench 128 128
	sudo bin/rbd create --size=40G mybench/image1

	sed -i "s/iodepth=.*/iodepth=${qd}/g" fio_write.fio
	sed -i "s/bs=.*/bs=${bs}/g" fio_write.fio
	sed -i "s/rw=.*/rw=${rw}/g" fio_write.fio
	sed -i "s/runtime=.*/runtime=${fioruntime}/g" fio_write.fio
	#sed -i "s/size=.*/size=${iototal}/g" fio_write.fio
        
        echo benchmark starts!
	echo $qd
        sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio fio_write.fio --output=dump-fio-bench-${qd} 
	sudo bin/ceph daemon osd.0 dump kvq vector
	mv ./kvq_lat_vec.csv ./dump_kvq_lat_vec-${qd}.csv
	mv ./kv_sync_lat_vec.csv ./dump_kv_sync_lat_vec-${qd}.csv
	mv ./txc_bytes_vec.csv ./dump_txc_bytes_vec-${qd}.csv
	mv ./kvq_lat_analysis_vec.csv ./dump_kvq_lat_analysis_vec-${qd}.csv
        # it contains kvq_p99_lat, kvq_p95_lat, kvq_median_lat, kvq_min_lat, kv_sync_p99_lat, kv_sync_p95_lat, kv_sync_median_lat, kv_sync_min_lat
        # process kvq_lat.csv and kv_cync_lat.csv
	INPUTCSV=dump_kvq_lat_analysis_vec-${qd}.csv
        kvq_p99_lat=$(awk 'BEGIN { FS = "," } ; NR == 2{ print $1 }' < $INPUTCSV)	
	kvq_p95_lat=$(awk 'BEGIN { FS = "," } ; NR == 3{ print $1 }' < $INPUTCSV)
	kvq_median_lat=$(awk 'BEGIN { FS = "," } ; NR == 4{ print $1 }' < $INPUTCSV)
	kvq_min_lat=$(awk 'BEGIN { FS = "," } ; NR == 5{ print $1 }' < $INPUTCSV)
	kv_sync_p99_lat=$(awk 'BEGIN { FS = "," } ; NR == 6{ print $1 }' < $INPUTCSV)
	kv_sync_p95_lat=$(awk 'BEGIN { FS = "," } ; NR == 7{ print $1 }' < $INPUTCSV)
	kv_sync_median_lat=$(awk 'BEGIN { FS = "," } ; NR == 8{ print $1 }' < $INPUTCSV)
	kv_sync_min_lat=$(awk 'BEGIN { FS = "," } ; NR == 9{ print $1 }' < $INPUTCSV)

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
#python plot_codel.py
# move everything to a directory
dn=queueing-delay-$(date +"%Y_%m_%d_%I_%M_%p")
sudo mkdir -p ${dn} # create data if not created
sudo mv dump* ${dn}
#sudo cp ceph.conf ${dn}
sudo mv ${dn} ./data
echo DONE!
#done
