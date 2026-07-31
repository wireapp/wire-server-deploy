#!/usr/bin/env python3

###############################################################
# Utility to derive statistics on packet captured RTP streams #
###############################################################

######################
# General Usage:
#
# First, capture a call's packets with tcpdump:
#
# kubenode1> tcpdump -i ens160 -s 0 -w testnumber.pcap host <client IP> and udp
#
# *place call from host here*
#
# Next, copy this pcap file to a place where you have these tools, and run this command on a pcap file to find out what udp ports were seen during the capture:
#
# adminhost> ./rtpstreams_graph.py testnumber.pcap
# usage: ./analyse_rtp_streams.py <pcap file> <port>
# finding source ports for you, be patient...
# pcap contains 21 packets with source port 37462
# pcap contains 29 packets with source port 38654
# pcap contains 67 packets with source port 80
# pcap contains 13 packets with source port 56899
# pcap contains 58 packets with source port 44279
# pcap contains 8340 packets with source port 50996
# pcap contains 5650 packets with source port 34096
# adminhost>
#
# Pick the port that has a lot of packets captured, as those are probably your calls.
#
# adminhost> ./rtpstreams_graph.py testnumber.pcap 50996
# capture file found. generating reports..
# Processing session 220450815 with 4180 packets
# <START REPORT>
# ...
# <END REPORT>
# Processing session 2008506802 with 3422 packets
# <START REPORT>
# ...
# <END REPORT>
#
# Copy everything between the start report, and the end report marker, and place it in a text file.
#
# Use generate_graph.pl to create a graph from your report!
#
# adminhost> ./generate_graph.pl report1.txt report1.png

##############################
# Interpreting these results:
#
# TL;dr: any packet delayed by more than 0:00:00.12 is problems. these will show as the red bars.
# delayed packets can cause SFT to lose track of the stream, and wait for the next keyframe.
# If there is no traffic shaping, the blue bars should be delayed corresponding to their packet sizes.

##################
# Requirements:
#
# If you're not using nix and direnv in our wire-server-deploy directory, you'll need:
# Python 3
# pyshark
# wireshark

import datetime
import sys
import time
import pyshark
import functools
import collections

BUCKETS = 10

if len(sys.argv) < 3:
    print('usage: {} <pcap file> <port>'.format(sys.argv[0]))

if len(sys.argv) == 1:
    exit (-1)

fname = sys.argv[1]
ss = dict()

if len(sys.argv) == 2:
    cap = pyshark.FileCapture (fname)
    print('Finding source ports for you, be patient...')
    for pkt in cap:
        if 'udp' in pkt:
            id = int(pkt.udp.srcport)
            if id not in ss:
                ss[id] = list()
            ss[id].append(pkt.udp.dstport)
    for id in ss:
        print ('pcap contains {} packets with source port {}'.format(len(ss[id]), id))
    exit (0)
            
port = sys.argv[2]
cap = pyshark.FileCapture (fname,
                           display_filter='udp',
                           decode_as={'udp.port=={}'.format(port):'rtp'})

print('Capture file found. Generating reports..')
for pkt in cap:
    # only keep rtp packets of type 100
    if 'rtp' in pkt and pkt.rtp.get('p_type') == '100':
        id = int(pkt.rtp.ssrc, 16)
        # bucket packets by which rtp session they belong to
        if id not in ss:
            ss[id] = list()
        ss[id].append(pkt)

for id in ss:
    print('Processing session {} with {} packets'.format(id, len(ss[id])))

    # sort packets by the time they were recorded by the filter program
    pkts = sorted(ss[id], key=lambda p: p.sniff_time)

    # retrieve the length of each packet, and the pairwise delay between
    # each packet and its predecessor. caution: this uses the length of the IP
    # datagram, not the length of the inner udp datagram.
    szdel = map(lambda i: {
        'size': int(pkts[i].length),
        'delay': pkts[i].sniff_time - pkts[i-1].sniff_time
    }, range(1, len(pkts)))

    # flatten timestamps into microseconds
    szdel = map(lambda i: {
        'size': i['size'],
        'delay': i['delay'].microseconds + (i['delay'].seconds * 1000000)
    }, szdel)

    # sort the list by packet size
    szdel = sorted(szdel, key=lambda p: p['size'])

    # split the list into N buckets by packet size
    bksz = len(szdel) / BUCKETS
    bknum = 0
    buckets = list()
    buckets.append(list())

    for i in range(0, len(szdel)):
        if i >= ((bknum + 1) * bksz) and (bknum + 1) < BUCKETS:
            bknum += 1
            buckets.append(list())

        buckets[bknum].append(szdel[i])

    # calculate the mean and max pairwise delay for each packet size bucket,
    # and retrieve the min and max size for labelling.
    avgs = map(lambda b: {
        'smin': min(map(lambda x: x['size'], b)),
        'smax': max(map(lambda x: x['size'], b)),
        'davg': functools.reduce(lambda x, y: x + y['delay'], b, 0) / len(b),
        'dmax': max(map(lambda x: x['delay'], b))
    }, buckets)

    avgs = list(avgs)

    print('<START REPORT>')
    # report
    for i in range(0, len(avgs)):
        a = avgs[i]
        lo = a['smin']
        hi = a['smax']
        print('{}-{} {} {}'.format(lo, hi, i+1, a['davg']))
        #              v-- gnuplot magic hacks.
        print('{}-{} {}.3 {}'.format(lo, hi, i+1, a['dmax']))
        print()
    print('<END REPORT>')
