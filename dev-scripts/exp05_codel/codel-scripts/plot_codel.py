import matplotlib.pyplot as plt
import numpy as np

data1 = np.loadtxt('dump-codel-tests.csv', delimiter=',', skiprows=1, unpack=True)

# rados bench lat vs thrput
plt.figure(1)
plt.plot(data1[5], data1[6], 'bo-')
plt.title('Rados Bench Latency vs Throughput')
plt.xlim(0)
plt.ylim(0)
plt.xlabel('avg throughput (MB/s)')
plt.ylabel('avg latency (s)')
plt.savefig("dump-rados-lat-bw.png", bbox_inches='tight')
