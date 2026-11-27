#!/usr/bin/env -S gnuplot -c
if (ARGC != 1) { print "usage: ", ARG0, " <svgfileout>";
                 exit -1
}

set terminal svg size 2560,1440 enhanced
set output ARG1

set xlabel "Time (seconds)"
set ylabel "Value"
set key outside

# “bars” as vertical lines (impulses)
set style data impulses

# possibilities:
#closed.dat         disconnect.dat  frame.dat      norestart.dat  open.dat        protocol.dat       servicestart.dat     socketTimeoutException.dat  workerRESULT.dat
#configREFRESH.dat  eof.dat         handshake.dat  onMessage.dat  persistent.dat  resultsuccess.dat  socketException.dat  workerOK.dat                workerSTART.dat


plot \
  "eof.dat" using 1:2 title "EOF" lc rgb "pink" lw 2, \
  "closed.dat" using 1:2 title "Closed"  lc rgb "red"   lw 2, \
  "open.dat" using 1:2 title "Open"    lc rgb "blue"  lw 2, \
  "handshake.dat" using 1:2 title "Handshake"    lc rgb "purple"  lw 2, \
  "frame.dat" using 1:2 title "Frames"  lc rgb "green" lw 2, \
  "configREFRESH.dat" using 1:2 title "Refresh" lc rgb "green" lw 2, \
  "disconnect.dat" using 1:2 title "Disconnect" lc rgb "orange" lw 2, \
