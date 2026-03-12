#!/usr/bin/env python3

##############################################################
# Utility to generate summary of packet captured RTP streams #
##############################################################

######################
# General Usage:
#
# capture packets with tcpdump:
#
# kubenode1> tcpdump -i ens160 -s 0 -w testnumber.pcap host <client IP> and udp
#
# run this command on a pcap file to find out what udp ports were seen during the capture
#
# Copy this pcap file to a place where you have these tools.
#
# adminhost> ./rtpstreams_summary.py testnumber.pcap
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
# Pick the big ones, as those are probably your calls.
#
# adminhost> ./rtpstreams_summary.py testnumber.pcap 50996
# Capture file found. Generating summary..
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

##############################
# Interpreting these results:
#
# TL;dr: any packet delayed by more than 0:00:00.12 is problems, and packet loss of above 0.1% can also be problematic.
# Both of these situations can cause SFT to lose track of the stream, and wait for the next keyframe.

###### Requirements:
# If you're not using nix and direnv in our wire-server-deploy directory, you'll need:
# Python 3
# pyshark
# wireshark

import datetime
import pyshark
import sys
import time

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
cap = pyshark.FileCapture(fname,
                          display_filter='udp',
                          decode_as={'udp.port=={}'.format(port):'rtp'})
seqs = {}
print('Capture file found. Generating summary..')

for packet in cap:
    if 'rtp' in packet:
        r = packet.rtp
        if r.get('p_type') == '100':
            ssrc = int(r.ssrc, 16)
            if ssrc not in seqs:
                seqs[ssrc] = []
            seqs[ssrc].append({'seq': int(r.seq),
                               'ts': int(r.timestamp),
                               'sts': packet.sniff_time})

for ssrc in seqs:
    print('SSRC {}: {} packets'.format(ssrc, len(seqs[ssrc])))
    pid = sorted(seqs[ssrc], key=lambda x: x['ts'])
    s = 0
    lastts = None
    maxts = datetime.timedelta(0)
    limitts = datetime.timedelta(seconds=0.12)
    lost = 0
    recv = 0
    rsnd = 0

    for pkt in pid:
        idx = pkt['seq']
        ts = pkt['sts']

        if lastts != None and ts - lastts > limitts:
            print('packet {} delayed by {}'.format(idx, ts-lastts))

        if lastts != None and ts - lastts > maxts:
            maxts = ts - lastts

        if s != 0 and idx >= s+1:
            lost += idx - s - 1
        elif s != 0 and idx == s:
            rsnd += 1

        lastts = ts
        s = idx
        recv += 1

    print('{} packets recved, {} lost ({} %) and {} with same seq'.format(recv, lost, int(lost * 100 / recv), rsnd))
    print('max delay between packets {}'.format(maxts))
