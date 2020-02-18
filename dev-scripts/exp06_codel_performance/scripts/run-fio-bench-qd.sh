#!/bin/bash
#sudo ../src/stop.sh
#sudo bin/init-ceph stop
#sleep 5

# run rbd bench and collect result
bs="4k" #block size or object size (Bytes)
#totaltime=120 # running time (seconds)
rw="randwrite"
iototal="400m"

# no need to change
osd_count=1            	 	# number of OSDs
shard_count=1           	# number of sharded op_queue
DATA_FILE=dump-codel-tests.csv  # output file name
pool="mybench"

single_dump() {
    qdepth=$1
    for o in $(seq 0 $(expr $osd_count - 1)) ; do
        dump_state="dump-state-${qdepth}"
        sudo bin/ceph daemon osd.0 perf dump 2>/dev/null > $dump_state
        #avg_throughput_bench=$(grep "Bandwidth (MB/sec)" dump-rados-bench-${qdepth} | awk '{print $3}')
        bluestore_kv_sync_lat=$(jq ".bluestore.kv_sync_lat.avgtime" $dump_state)
        bluestore_kvq_lat=$(jq ".bluestore.bluestore_kvq_lat.avgtime" $dump_state)
        printf '%s\n' $bs $iototal $qdepth $bluestore_kv_sync_lat $bluestore_kvq_lat  | paste -sd ',' >> ${DATA_FILE}
    done
    #sudo bin/ceph daemon osd.0 perf reset osd
}

printf '%s\n' "bs" "iototal" "qdepth" "bluestore_kv_sync_lat" "bluestore_kvq_lat" |  paste -sd ',' > ${DATA_FILE}
#for qd in 1 16 32 48 64 80 96 112 128;do
for qd in 16 32 48 64 80 96; do
#for qd in 32; do
        #./run.sh $qd $bt
        #sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -b -k -l --without-dashboard
        #sudo bin/ceph osd pool create $pool 128 128
	#sudo MON=1 OSD=1 MDS=0 ../src/vstart.sh -n -o 'bluestore block = /dev/sdc' -o 'bluestore block path = /dev/sdc' -o 'bluestore fsck on mkfs = false' -o 'bluestore fsck on mount = false' -o 'bluestore fsck on umount = false' -o 'bluestore block db path = ' -o 'bluestore block wal path = ' -o 'bluestore block wal create = false' -o 'bluestore block db create = false' --without-dashboard
	./start_ceph.sh
	sudo bin/ceph osd pool create mybench 128 128
	sudo bin/rbd create --size=1G mybench/image1

	sed -i "s/iodepth=.*/iodepth=${qd}/g" fio_write.fio
	sed -i "s/bs=.*/bs=${bs}/g" fio_write.fio
	sed -i "s/rw=.*/rw=${rw}/g" fio_write.fio
	sed -i "s/size=.*/size=${iototal}/g" fio_write.fio
        
        echo benchmark starts!
	#sudo bin/rbd -p mybench bench image1 --io-type $iotype --io-size $bs --io-threads $qd --io-total $iototal --io-pattern $iopattern 2>&1 | tee  dump-rbd-bench-${qd}
        sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio fio_write.fio --output=dump-fio-bench-${qd} 
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
dn=codel-tests-$(date +"%Y_%m_%d_%I_%M_%p")
sudo mkdir -p ${dn} # create data if not created
sudo mv dump* ${dn}
#sudo cp ceph.conf ${dn}
sudo mv ${dn} ./data
echo DONE!

