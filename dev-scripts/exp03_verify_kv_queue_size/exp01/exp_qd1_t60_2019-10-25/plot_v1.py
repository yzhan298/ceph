import matplotlib.pyplot as plt
import numpy as np

data = np.loadtxt('dump-result.csv', delimiter=',', skiprows=2, unpack=True)

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

# check kv_queue_size vs workload concurrency
plt.figure(3)
plt.plot(data[2], data[4], 'bo-')
plt.title('BlueStore Queue Size')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('Workload Concurrency')
plt.ylabel('Kv Queue Size')
plt.savefig("dump_kvq_vs_qd.png", bbox_inches='tight')

#plt.show()
