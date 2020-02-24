import matplotlib.pyplot as plt
import numpy as np
from pandas import read_csv
import glob

# process raw data (these csvs are raw data)
# use (eg: nrows=50) to control how many data points are needed
for f in glob.glob('dump_opq_vec*.csv'):
	data1 = read_csv(f, header=0, skiprows=11, parse_dates=True, squeeze=True)
	fig1 = plt.figure(1)
	ax1 = fig1.add_subplot(111)
	line1 = data1.plot(style='bo-', label='op_queue_size')
	ax1.set_xlabel('measurement points')
	ax1.set_ylabel('op_queue size')
	#plt.show()
	figname=f.split(".")[0] + ".png"
	plt.savefig(figname, bbox_inches='tight')
	plt.close()

for f in glob.glob('dump_blocking_dur_vec*.csv'):
	data1 = read_csv(f, header=0, skiprows=11, parse_dates=True, squeeze=True)
	fig1 = plt.figure(1)
	ax1 = fig1.add_subplot(111)
	line1 = data1.plot(style='bo-', label='blocking_dur')
	ax1.set_xlabel('measurement points')
	ax1.set_ylabel('blocking_duration(s)')
	#plt.show()
	figname=f.split(".")[0] + ".png"
	plt.savefig(figname, bbox_inches='tight')
	plt.close()

for f in glob.glob('dump_kv_queue_size_vec*.csv'):
	data1 = read_csv(f, header=0, skiprows=11, parse_dates=True, squeeze=True)
	fig1 = plt.figure(1)
	ax1 = fig1.add_subplot(111)
	line1 = data1.plot(style='bo-', label='kv_queue_size')
	ax1.set_xlabel('measurement points')
	ax1.set_ylabel('kv_queue size')
	#plt.show()
	figname=f.split(".")[0] + ".png"
	plt.savefig(figname, bbox_inches='tight')
	plt.close()

for f in glob.glob('dump_kv_sync_lat_vec*.csv'):
	data1 = read_csv(f, header=0, skiprows=11, parse_dates=True, squeeze=True)
	fig1 = plt.figure(1)
	ax1 = fig1.add_subplot(111)
	line1 = data1.plot(style='bo-', label='kv_sync_lat')
	ax1.set_xlabel('measurement points')
	ax1.set_ylabel('kv_sync_lat')
	#plt.show()
	figname=f.split(".")[0] + ".png"
	plt.savefig(figname, bbox_inches='tight')
	plt.close()

for f in glob.glob('dump_kvq_lat_vec*.csv'):
	data1 = read_csv(f, header=0, skiprows=11, parse_dates=True, squeeze=True)
	fig1 = plt.figure(1)
	ax1 = fig1.add_subplot(111)
	line1 = data1.plot(style='bo-', label='kv_queueing_lat')
	ax1.set_xlabel('measurement points')
	ax1.set_ylabel('kv_queueing_lat')
	#plt.show()
	figname=f.split(".")[0] + ".png"
	plt.savefig(figname, bbox_inches='tight')
	plt.close()

for f in glob.glob('dump_txc_bytes_vec*.csv'):
	data1 = read_csv(f, header=0, skiprows=11, parse_dates=True, squeeze=True)
	fig1 = plt.figure(1)
	ax1 = fig1.add_subplot(111)
	line1 = data1.plot(style='bo-', label='txc_bytes')
	ax1.set_xlabel('measurement points')
	ax1.set_ylabel('txc_bytes')
	#plt.show()
	figname=f.split(".")[0] + ".png"
	plt.savefig(figname, bbox_inches='tight')
	plt.close()

# these csvs are processed and gethered in Ceph
# first and last 10 points are removed
data1 = np.loadtxt('dump-lat-analysis.csv', delimiter=',', skiprows=1, unpack=True)
plt.figure(1)
plt.plot(data1[0], data1[3], 'bo-', label="bs_kv_sync_lat")
plt.plot(data1[0], data1[5], 'go-', label="kv_sync_p99_lat")
plt.plot(data1[0], data1[6], 'ro-', label="kv_sync_p95_lat")
plt.plot(data1[0], data1[7], 'co-', label="kv_sync_median_lat")
plt.plot(data1[0], data1[8], 'yo-', label="kv_sync_min_lat")

plt.title("BlueStore KV Sync Latency(5 curves)", y=1.02)
#plt.xlim(0)
plt.xscale('log')
plt.yscale('log')
plt.xlabel('workload block size')
plt.ylabel('Latencies (s)')
plt.legend()
#plt.show()
plt.savefig("dump-bs-kv-sync-lat-analysis.png", bbox_inches='tight')
plt.close()






