import matplotlib.pyplot as plt
import numpy as np

data = np.loadtxt('dump-result-sampling.csv', delimiter=',', skiprows=2, unpack=True)

# check op_queue_size
plt.figure(1)
plt.plot(data[3], 'bo-')
plt.title('Op Queue Size Over Time')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Time')
plt.ylabel('Op Queue Size')
plt.savefig("dump_op_queue.png", bbox_inches='tight')

#check kv_queue_size
plt.figure(2)
plt.plot(data[4], 'bo-')
plt.title('BlueStore Queue Size')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Time')
plt.ylabel('Kv Queue Size')
plt.savefig("dump_kv_queue.png", bbox_inches='tight')

'''
data1 = np.loadtxt('dump-result-single-dump.csv', delimiter=',', skiprows=2, unpack=True)
# check kv_queue_size vs bluestore latency(from KV_PREPARED TO KV_FINISHED)
plt.figure(3)
plt.plot(data1[5], data1[7], 'bo-')
plt.title('BlueStore Latency vs KV Queue Size')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Average KV Queue Size')
plt.ylabel('Average BlueStore Latency')
plt.savefig("dump_avgkvq_vs_bslat.png", bbox_inches='tight')

# check kv_queue_size vs bluestore kv_sync_latency
plt.figure(3)
plt.plot(data1[5], data1[6], 'bo-')
plt.title('BlueStore KV Sync Latency vs KV Queue Size')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Average KV Queue Size')
plt.ylabel('Average BlueStore KV Sync Latency')
plt.savefig("dump_avgkvq_vs_kvlat.png", bbox_inches='tight')
'''
#plt.show()
