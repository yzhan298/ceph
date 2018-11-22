# generated Wed Oct 10 09:34:04 PDT 2018
using Plots
gr()
x = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20
 ]
queue_size = [ ,,,,,,,,,,,,,,,,,,, ]
latency = [ ,,,,,,,,,,,,,,,,,,, ]
plot(x, queue_size, label="op queue size (ops)", legend=:bottomleft, ylim=(0,Inf), markershape=:auto, title="Throtte NO, Iteration 1")
t = twinx()
plot!(t, x, latency, label="write latency (secs)", color=:red, legend=:bottomright, ylim=(0,Inf), title="Throtte NO, Iteration 1", markershape=:auto)
savefig("queue_size_1_NO_full.pdf")
