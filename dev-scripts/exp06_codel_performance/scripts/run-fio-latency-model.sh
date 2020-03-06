#!/bin/bash
#sudo ../src/stop.sh
#sudo bin/init-ceph stop
#sleep 5

# run rbd bench and collect result
bs="4096" #block size or object size (Bytes)
rw="randwrite"
fioruntime=30
iototal="400m"
qd=48

# no need to change
osd_count=1            	 	# number of OSDs
shard_count=1           	# number of sharded op_queue
DATA_FILE=dump-lat-analysis.csv  # output file name
pool="mybench"

single_dump() {
    blocksize=$1
    for o in $(seq 0 $(expr $osd_count - 1)) ; do
        dump_state="dump-state-${blocksize}"
        sudo bin/ceph daemon osd.0 perf dump 2>/dev/null > $dump_state
	clt_bw=$(echo "$(jq '.jobs[0].write.bw' dump-fio-bench-${blocksize}) / 1024" | bc -l) # MB/s
        clt_lat=$(echo "$(jq '.jobs[0].write.lat_ns.mean' dump-fio-bench-${blocksize}) / 1000000000" | bc -l) # seconds
        bluestore_kv_sync_lat=$(jq ".bluestore.kv_sync_lat.avgtime" $dump_state)
        bluestore_kvq_lat=$(jq ".bluestore.bluestore_kvq_lat.avgtime" $dump_state)
        printf '%s\n' $bs $iototal $qd $clt_bw $clt_lat $bluestore_kv_sync_lat $bluestore_kvq_lat $kv_sync_p99_lat $kv_sync_p95_lat $kv_sync_median_lat $kv_sync_min_lat $kvq_p99_lat $kvq_p95_lat $kvq_median_lat $kvq_min_lat | paste -sd ',' >> ${DATA_FILE}
    done
    #sudo bin/ceph daemon osd.0 perf reset osd
}

#for j in 1 2 3 4 5; do
printf '%s\n' "bs" "iototal" "qdepth" "bw_mbs" "lat_s" "bluestore_kv_sync_lat" "bluestore_kvq_lat" "kv_sync_p99_lat" "kv_sync_p95_lat" "kv_sync_median_lat" "kv_sync_min_lat" "kvq_p99_lat" "kvq_p95_lat" "kvq_median_lat" "kvq_min_lat" |  paste -sd ',' > ${DATA_FILE}
for i in {0..10}; do
#for i in 11; do
#for qd in 32; do
        #./run.sh $qd $bt
        #sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -k -l --without-dashboard
        #sudo bin/ceph osd pool create $pool 128 128
	#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -n -o 'bluestore block = /dev/sdc' -o 'bluestore block path = /dev/sdc' -o 'bluestore fsck on mkfs = false' -o 'bluestore fsck on mount = false' -o 'bluestore fsck on umount = false' -o 'bluestore block db path = ' -o 'bluestore block wal path = ' -o 'bluestore block wal create = false' -o 'bluestore block db create = false' --without-dashboard
	bs="$((2**i*4*1024))"
	iototal="$((2**i*4*1024*10000))"   #"$((2**i*40))m"
	./start_ceph.sh
	sudo bin/ceph osd pool create mybench 128 128
	sudo bin/rbd create --size=40G mybench/image1

	sed -i "s/iodepth=.*/iodepth=${qd}/g" fio_write.fio
	sed -i "s/bs=.*/bs=${bs}/g" fio_write.fio
	sed -i "s/rw=.*/rw=${rw}/g" fio_write.fio
	sed -i "s/runtime=.*/runtime=${fioruntime}/g" fio_write.fio
	#sed -i "s/size=.*/size=${iototal}/g" fio_write.fio
        
        echo benchmark starts!
	echo $bs
	echo $iototal
	#sudo bin/rbd -p mybench bench image1 --io-type $iotype --io-size $bs --io-threads $qd --io-total $iototal --io-pattern $iopattern 2>&1 | tee  dump-rbd-bench-${qd}
        sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio fio_write.fio --output-format=json --output=dump-fio-bench-${bs} 
	sudo bin/ceph daemon osd.0 dump kvq vector
	mv ./kvq_lat_vec.csv ./dump_kvq_lat_vec-${bs}.csv
	mv ./kv_sync_lat_vec.csv ./dump_kv_sync_lat_vec-${bs}.csv
	mv ./txc_bytes_vec.csv ./dump_txc_bytes_vec-${bs}.csv
	mv ./kvq_lat_analysis_vec.csv ./dump_kvq_lat_analysis_vec-${bs}.csv
	mv ./kv_queue_size_vec.csv ./dump_kv_queue_size_vec-${bs}.csv
        mv ./blocking_dur_vec.csv ./dump_blocking_dur_vec-${bs}.csv
        # it contains kvq_p99_lat, kvq_p95_lat, kvq_median_lat, kvq_min_lat, kv_sync_p99_lat, kv_sync_p95_lat, kv_sync_median_lat, kv_sync_min_lat
        # process kvq_lat.csv and kv_cync_lat.csv
	INPUTCSV=dump_kvq_lat_analysis_vec-${bs}.csv
        kvq_p99_lat=$(awk 'BEGIN { FS = "," } ; NR == 2{ print $1 }' < $INPUTCSV)	
	kvq_p95_lat=$(awk 'BEGIN { FS = "," } ; NR == 3{ print $1 }' < $INPUTCSV)
	kvq_median_lat=$(awk 'BEGIN { FS = "," } ; NR == 4{ print $1 }' < $INPUTCSV)
	kvq_min_lat=$(awk 'BEGIN { FS = "," } ; NR == 5{ print $1 }' < $INPUTCSV)
	kv_sync_p99_lat=$(awk 'BEGIN { FS = "," } ; NR == 6{ print $1 }' < $INPUTCSV)
	kv_sync_p95_lat=$(awk 'BEGIN { FS = "," } ; NR == 7{ print $1 }' < $INPUTCSV)
	kv_sync_median_lat=$(awk 'BEGIN { FS = "," } ; NR == 8{ print $1 }' < $INPUTCSV)
	kv_sync_min_lat=$(awk 'BEGIN { FS = "," } ; NR == 9{ print $1 }' < $INPUTCSV)

	sudo bin/ceph daemon osd.0 dump opq vector
        mv ./opq_vec.csv ./dump_opq_vec-${bs}.csv

	single_dump $bs
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
dn=latency-model-$(date +"%Y_%m_%d_%I_%M_%p")
sudo mkdir -p ${dn} # create data if not created
sudo mv dump* ${dn}
sudo mv ${dn} ./data
echo DONE!
#done
