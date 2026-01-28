#!/usr/bin/env -S gnuplot -c

####################################################################
# GNUPlot script to display reports on packet captured RTP streams #
####################################################################

##############################
# General Usage
#
# once you have a report from rtpstreams_graph.py saved to a file,
# provide it to this utility, and get a graphical output.

##############################
# Requirements
#
# If you're not using wire-server-deploy's direnv and nix setup,
# you will need to install a version of gnuplot greater than version 5.

if (ARGC != 2) { print "usage: ", ARG0, " <txtfilein> <pngfileout>";
		 exit -1
}

set boxwidth 0.3
set style fill solid

set style line 1 lc rgb "blue"
set style line 2 lc rgb "red"

set term pngcairo size 1024,768 enhance font 'Verdana,10'

set title "Packet size against mean pairwise transmission delay"

set xlabel "Packet size ranges per bucket (bytes)"
set xrange [0:]
set ylabel "Packet-pairwise transmission delay (microseconds)"
set yrange [0:]

set output ARG2

plot sprintf("<cat %s",ARG1) every 2    using 2:3:xtic(1) with boxes ls 1 title 'Mean packet delay in bucket', \
                   ''        every 2::1 using 2:3         with boxes ls 2 title 'Max packet delay in bucket'
