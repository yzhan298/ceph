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
plt.savefig("dump_op_queue_sampling.png", bbox_inches='tight')

#check kv_queue_size
plt.figure(2)
plt.plot(data[4], 'bo-')
plt.title('BlueStore Queue Size')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Time')
plt.ylabel('Kv Queue Size')
plt.savefig("dump_kv_queue_sampling.png", bbox_inches='tight')

# plot every kv_queue size from osd.log
data1 = np.loadtxt('dump-kvq-size.csv', unpack=True)
plt.figure(3)
plt.plot(data1, 'bo')
plt.title('BlueStore Every KV Queue Size')
plt.xlim(0)
plt.ylim(0)
#plt.xlabel('')
plt.ylabel('Every KV Queue Size')
plt.savefig("dump_every_kvq_size.png", bbox_inches='tight')

# histogram of kv_queue size
plt.figure(4)
n, bins, patches = plt.hist(data1, bins=5, color='#0504aa',alpha=0.7, rwidth=0.85)
plt.savefig("dump_kvq_hist.png", bbox_inches='tight')

#plt.show()
