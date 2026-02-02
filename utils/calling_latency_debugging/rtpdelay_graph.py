#!/usr/bin/env python3

###################################################################
# Utility to generate delay graphs on packet captured RTP streams #
###################################################################

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
# adminhost> ./rtpstreams_summary.py testnumber.pcap
# usage: ./rtpstreams_graph.py <pcap file> <port>
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
# If you want to graph a single session, use rtpstreams_graph to get your session numbers. otherwise, skip to the next step.
#
# adminhost> ./rtpstreams_summary.py testnumber.pcap 50996
# capture file found. generating summary..
# SSRC 220450815: 4180 packets
# packet 27697 delayed by 0:00:00.137442
# packet 27705 delayed by 0:00:00.310505
# 4180 packets recved, 0 lost (0 %) and 0 with same seq
# max delay between packets 0:00:00.310505
# SSRC 2008506802: 3422 packets
# packet 257 delayed by 0:00:00.142737
# packet 271 delayed by 0:00:00.160726
# packet 491 delayed by 0:00:00.169627
# packet 640 delayed by 0:00:00.182204
# packet 1261 delayed by 0:00:00.121933
# packet 1614 delayed by 0:00:00.200193
# packet 1945 delayed by 0:00:00.168273
# packet 2059 delayed by 0:00:00.127896
# packet 2639 delayed by 0:00:00.169698
# packet 2761 delayed by 0:00:00.132851
# packet 2781 delayed by 0:00:00.160073
# 3422 packets recved, 64 lost (1 %) and 0 with same seq
# max delay between packets 0:00:00.200193
#
# The values you're looking for are on the lines that begin with SSRC.
#
# Now use this program to graph a single session, or multiple sessions.
#
# adminhost> ./rtpdelay_graph.py testnumber.pcap 50996 220450815
# Capture file found. Generating graph..
# SSRC 220450815: 4180 packets
#
# You should now have a file named testnumber.pcap.png with your graph in it.


import datetime
import matplotlib.pyplot as plt
import pyshark
import sys
import time

# colours for the lines
colors = ['blue', 'red', 'green', 'cyan', 'magenta']

if len(sys.argv) < 3 or len(sys.argv) > 4:
        print('usage: {} <pcap file> <port> [ssrc]'.format(sys.argv[0]))

if len(sys.argv) == 1:
    exit (-1)

fname = sys.argv[1]

if len(sys.argv) == 2:
    ss = dict()
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
if len(sys.argv) == 4:
    selssrc = int(sys.argv[3])
else:
    selssrc = None

# get the packets from tshark
cap = pyshark.FileCapture(fname,
                          display_filter='udp',
                          decode_as={'udp.port=={}'.format(port):'rtp'})

seqs = {}

print('Capture file found. Generating graph..')
for packet in cap:
    if 'rtp' in packet and packet.rtp.get('p_type') == '100':
        r = packet.rtp
        # video p_type=100, audio 111, video via TURN 98
        ssrc = int(r.ssrc, 16)
        if ssrc not in seqs:
            seqs[ssrc] = []

        # store the relevant info for later
        seqs[ssrc].append({'seq': int(r.seq),
                           'ts': int(r.timestamp),
                           'sniffts': packet.sniff_time})

c = 0

for ssrc in seqs:

    # if an SSRC is given, skip the others
    if selssrc != None and ssrc != selssrc:
        continue

    print('SSRC {}: {} packets'.format(ssrc, len(seqs[ssrc])))

    # sort by the RTP packet ts (source ts)
    pid = sorted(seqs[ssrc], key=lambda x: x['seq'])
    s = 0

    # use first packet for offsets
    firstseq = pid[0]['seq']
    firstts = pid[0]['ts']
    firstsniffts = pid[0]['sniffts']

    x = []
    y = []

    for pkt in pid:
        # calculate ts diff from first packet
        # video RTP packet ts is in 1/90000s so do ts*1000/90 for us
        pts = int((pkt['ts'] - firstts) * 1000 / 90)

        # calculate sniffed ts from first packet
        sniffts = (pkt['sniffts'] - firstsniffts)
        psniffts = sniffts.seconds * 1000000 + sniffts.microseconds

        tsdiff = psniffts - pts

        #print('{} {}'.format(pkt['seq'] - firstseq, tsdiff))
        x.append(pkt['seq'] - firstseq)
        y.append(tsdiff / 1000)

    plt.plot(x, y, color=colors[c], linestyle='solid', linewidth=1, label='{}'.format(ssrc))

    # next colour
    c += 1

plt.xlabel('Packet seqNo')
plt.ylabel('Delay relative to first packet (ms)')

plt.savefig('{}.png'.format(fname), pad_inches=0.2)
                                                                                                                                                                                                                                            
