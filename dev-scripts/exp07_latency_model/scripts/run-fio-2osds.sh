#!/bin/bash

# run rbd bench and collect result
bs="4096"   #"131072"  # block size 
rw="randwrite"  # io type
fioruntime=300  # seconds
iototal="400m" # total bytes of io
#qd=48 # workload queue depth

# no need to change
pool="mybench"
dn=${rw}-${bs}-$(date +"%Y_%m_%d_%I_%M_%p")
sudo mkdir -p ${dn} # create data if not created

# change accordingly
osd_num=2

for qd in 48; do
	#bs="$((2**i*4*1024))"
	#iototal="$((2**i*4*1024*100000))"   #"$((2**i*40))m"
	
	#------------- clear rocksdb debug files -------------#
	sudo rm /tmp/flush_job_timestamps.csv  /tmp/compact_job_timestamps.csv
	
	#------------- start cluster -------------#
	./start_ceph.sh
	sudo bin/ceph osd pool create mybench 128 128
	sudo bin/rbd create --size=1G mybench/image1
	for o in $(seq 0 $(expr $osd_num - 1)) ; do
		sudo bin/ceph daemon osd.${o} config show | grep bluestore_rocksdb
	done
	sudo bin/ceph -s
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
	sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio fio_prefill_rbdimage.fio
	#------------- clear debug files and reset counters -------------#
	sudo rm /tmp/flush_job_timestamps.csv  /tmp/compact_job_timestamps.csv
	# reset the perf-counter
	sudo echo 3 | sudo tee /proc/sys/vm/drop_caches && sudo sync
	for o in $(seq 0 $(expr $osd_num - 1)) ; do
		sudo bin/ceph daemon osd.${o} perf reset osd >/dev/null 2>/dev/null
		# reset admin socket of OSD and BlueStore
		sudo bin/ceph daemon osd.${o} reset kvq vector
		#sudo bin/ceph daemon osd.${o} reset opq vector
	done

	#------------- benchmark -------------#
	echo benchmark starts!
	echo $qd
    	sudo LD_LIBRARY_PATH="$CEPH_HOME"/build/lib:$LD_LIBRARY_PATH "$FIO_HOME"/fio fio_write.fio --output-format=json --output=dump-fio-bench-${qd}.json 
	
	# dump internal data with admin socket
	for o in $(seq 0 $(expr $osd_num - 1)) ; do
		# BlueStore
		sudo bin/ceph daemon osd.${o} dump kvq vector	
		# OSD
		#sudo bin/ceph daemon osd.${o} dump opq vector
		# move to osd-${o}
		mkdir osddump${o}
		sudo mv dump* osddump${o}
	done
	# rbd info
	sudo bin/rbd info mybench/image1 | tee dump_rbd_info.txt
	# get rocksdb debug files
	sudo cp /tmp/compact_job_timestamps.csv /tmp/flush_job_timestamps.csv ${dn}
    	echo benchmark stops!
	sudo bin/ceph -s

	#------------- stop cluster -------------#
	sudo bin/rbd rm mybench/image1
    	sudo bin/ceph osd pool delete $pool $pool --yes-i-really-really-mean-it
    	sudo ../src/stop.sh
	
done

# move everything to a directory
sudo mv dump* ${dn}
sudo cp plot-bluestore-lat.py osddump1
for o in $(seq 0 $(expr $osd_num - 1)) ; do
	sudo cp plot-bluestore-lat.py osddump${o}
done
sudo mv osddump* ${dn}
sudo cp ceph.conf ${dn}
sudo cp fio_write.fio ${dn}
sudo cp plot-bluestore-lat.py ${dn}
sudo mv ${dn} ./data
echo DONE!
#done
for o in $(seq 0 $(expr $osd_num - 1)) ; do
	sudo python3 ./osddump${o}/plot-bluestore-lat.py
done
