set terminal svg size 2560,1440 enhanced
set output "websocket.svg"

set xlabel "Time (seconds)"
set ylabel "Value"
set key outside

# “bars” as vertical lines (impulses)
set style data impulses

plot \
  "closed.dat" using 1:2 title "Closed"  lc rgb "red"   lw 2, \
  "open.dat" using 1:2 title "Open"    lc rgb "blue"  lw 2, \
  "frame.dat" using 1:2 title "Frames"  lc rgb "green" lw 2