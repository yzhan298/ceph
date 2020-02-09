from pandas import read_csv
import matplotlib.pyplot as plt
import os

series = read_csv(os.environ['PLOTINNAME'])
series.plot()
plt.xlabel('time')
plt.ylabel('latency (s)')
plt.savefig(os.environ['PLOTOUTNAME'], bbox_inches='tight')

