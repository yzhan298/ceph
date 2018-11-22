#!/bin/sh

# you may want to change the # of iterations

iterations=1

# the three different types of run, we run of each type per iteration;
# in other words each iteration produces three test runs
options="NO OLD NEW"

where=$(dirname $0)
for i in $(seq -s ' ' $iterations) ;do
    for o in $options ;do
	# copy the appropriate ceph.conf.XXX file to ceph.conf for test
	cp -f ceph.conf.${o} ceph.conf

	# run the test
	${where}/load-ceph.sh

	# process the output files
	for f in oio_out* ;do
	    new=$(echo $f | sed "s/_out/_rates/")
	    mv $f ${new}_${o}_${i}
	done
	mv oio_queue_size_out oio_queue_size_out_${o}_${i}
    done
done
