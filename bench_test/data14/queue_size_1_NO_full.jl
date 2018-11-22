# generated Wed Nov 21 09:53:53 PST 2018
using Plots
gr()
x = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20
 ]
queue_size = [ 38,0,2,0,0,0,34,0,0,40,0,0,40,9,9,0,0,0,16,0 ]
latency = [ 3.399679745,1.707111881,0.463599912,0.45021868,22.351627589,0.645604392,0.595194355,0.546811673,4.296404448,1.231504613,0.575757706,0.558690588,3.251889325,1.199095522,0.533572197,0.456690176,2.16168527,1.339502266,0.426827622,0.508170549 ]
plot(x, queue_size, label="op queue size (ops)", legend=:bottomleft, ylim=(0,Inf), markershape=:auto, title="Throtte NO, Iteration 1")
t = twinx()
plot!(t, x, latency, label="write latency (secs)", color=:red, legend=:bottomright, ylim=(0,Inf), title="Throtte NO, Iteration 1", markershape=:auto)
savefig("queue_size_1_NO_full.pdf")
