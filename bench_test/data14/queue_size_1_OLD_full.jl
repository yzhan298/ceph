# generated Wed Nov 21 09:53:53 PST 2018
using Plots
gr()
x = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20
 ]
queue_size = [ 157,157,156,164,170,156,152,156,155,155,153,155,155,155,155,155,155,155,154,155 ]
latency = [ 0.762710026,1.106929145,0.704803978,0.479261321,0.727399143,0.475844439,0.920149651,0.71400421,0.764729346,1.253884997,0.894820393,1.099913651,0.898590776,1.255130375,0.962753569,1.025449745,1.104821412,0.955154274,1.187336023,0.87912537 ]
plot(x, queue_size, label="op queue size (ops)", legend=:bottomleft, ylim=(0,Inf), markershape=:auto, title="Throtte OLD, Iteration 1")
t = twinx()
plot!(t, x, latency, label="write latency (secs)", color=:red, legend=:bottomright, ylim=(0,Inf), title="Throtte OLD, Iteration 1", markershape=:auto)
savefig("queue_size_1_OLD_full.pdf")
