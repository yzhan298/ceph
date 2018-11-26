#!/bin/sh

iterations=1
osds=1
timepoints=18

remove_end() {
    echo "$1" | sed "s/${2}$//"
}

for a in NO OLD NEW ;do
    for i in $(seq $iterations) ;do
	base="queue_size_${i}_${a}_full"
	out="${base}.jl"
	echo "# generated $(date)" >$out
	# echo "using DataFrames, Gadfly" >>$out
	# echo "data = DataFrame()" >>$out

	echo "using Plots" >>$out
	echo "gr()" >>$out
	/bin/echo -n "x = [ " >>$out
	seq -s ", " 1 $timepoints >>$out
	echo " ]" >>$out

	unset size osd throttle time latency

	for t in $(seq 1 $timepoints) ;do
	    in="oio_queue_size_out_${a}_${i}"
	    for o in $(seq 0 $(expr $osds - 1)) ;do
		s=$( egrep "^${t}\.${o}\." $in | sed -e 's/.* //' | tr '\n' '+' | sed 's/\+$/\
/' | bc )
		size="${size}$s,"
		osd="${osd}\"$o\","
		time="${time}$t,"
	    done
	    l=$( egrep "^${t}\.${o}#osd_op_w_latency" $in | sed -e 's/.* //' )
	    latency="${latency}$l,"
	done

	time=$(remove_end $time ,)
	size=$(remove_end $size ,)
	osd=$(remove_end $osd ,)
	latency=$(remove_end $latency ,)

	# echo "data[:time] = [ $time ]" >>$out
	echo "queue_size = [ $size ]" >>$out
	# echo "data[:osd] = [ $osd ]" >>$out
	echo "latency = [ $latency ]" >>$out

	# echo 'p = Gadfly.plot(data, xgroup="time", x="throttle", y="queue_size", color="osd", Geom.subplot_grid(Geom.bar(position=:stack)), Scale.y_continuous(maxvalue=200))' >>$out
	# echo 'p = Gadfly.plot(data, xgroup="time", x="throttle", y="queue_size", color="osd", Geom.subplot_grid(Geom.bar(position=:stack)))' >>$out

	# echo "draw(PDF(\"queue_size_${i}.pdf\", 8inch, 5inch), p)" >>$out

	echo "plot(x, queue_size, label=\"op queue size (ops)\", legend=:bottomleft, ylim=(0,Inf), markershape=:auto, title=\"Throtte $a, Iteration $i\")" >>$out
	echo "t = twinx()" >>$out
	echo "plot!(t, x, latency, label=\"write latency (secs)\", color=:red, legend=:bottomright, ylim=(0,Inf), title=\"Throtte $a, Iteration $i\", markershape=:auto)" >>$out
	pdfout="${base}.pdf"
	echo "savefig(\"$pdfout\")" >>$out
    done
done
