#!/usr/bin/env python
#
# Programmed by Keehyoung Joo at KIAS
# newton@kias.re.kr

# Modified by Daniel Berenberg @ the Flatiron Institute

import argparse
import os, sys, string
from math import log
from pathlib import Path

import numpy as np
import array

SANN_HOME = os.environ.get("SANN")
QIJ       = str(SANN_HOME / 'bin' / 'qij')

mapping=[0,4,3,6,13,7,8,9,11,10,12,2,14,5,1,15,16,19,17,18]
aaNum = {'A': 0,'C': 1,'D': 2,'E': 3,'F': 4,
         'G': 5,'H': 6,'I': 7,'K': 8,'L': 9,
         'M':10,'N':11,'P':12,'Q':13,'R':14,
         'S':15,'T':16,'V':17,'W':18,'Y':19,'X':0}
blos_aa= [0,14,11,2,1,13,3,5,6,7,9,8,10,4,12,15,16,18,19,17]

def arguments():
    parser = argparse.ArgumentParser(description="mkchk - called from sann.sh")
    parser.add_argument("checkfile", help=".chk file from BLAST", type=Path)
    parser.add_argument("--qij", help="path to qij", type=str, default=QIJ)
    return parser.parse_args()


def read_qij(file):
    file = open(file)
    qij = np.zeros((20,20), dtype=np.float64)
    i=0
    for line in file.readlines():
        val = list(map(float, line.split()))
        for j in range(len(val)):
            qij[blos_aa[i],blos_aa[j]] = val[j]
            qij[blos_aa[j],blos_aa[i]] = val[j]
        i+=1
    for i in range(20):
        sum = 0.0
        for j in range(20):
            sum += qij[i,j]
        for j in range(20):
            qij[i,j] = qij[i,j]/sum
    return qij

def read_chk(chkfile):
    with open(chkfile, mode='rb') as checkfile:
        n = array.array('i')
        n.fromfile(checkfile, 1)
        naa = n[0]

        strarr = array.array('b')
        strarr.fromfile(checkfile,naa)
        seq = strarr.tostring()
        seq = seq.decode('utf-8')

        print(f"Sequence: {seq} ({naa} residues)")
        aa_types = 20
        
        out     = np.zeros((naa, aa_types), dtype=np.float64)
        col     = np.zeros((naa), dtype=int)
        quality = np.zeros((naa), dtype=np.float64)

        for i, amino in enumerate(seq):
            v = array.array('d')
            v.fromfile(checkfile, aa_types)
            data = np.array(v, dtype=np.float64)
            if not sum(data):
                col[i] = 0
                for j in range(aa_types):
                    out[i, j] =  qij[aaNum[amino], j]
            else:
                col[i] = 1
                for j in range(aa_types):
                    out[i, j] = data[mapping[j]]
            
            for k in range(aa_types):
                quality[i] = quality[i] - out[i,k]*log(out[i,k])
    return naa, seq, out, col, quality
    
if __name__ == '__main__':
    args = arguments()

    chkfile = args.checkfile.with_suffix(".chk")

    qij = read_qij(args.qij)

    naa, seq, out, col, quality = read_chk(chkfile)

    with open(chkfile.parent / f"{chkfile.stem}.ck2" , 'w') as ck2file:
        print(naa, file=ck2file)
        print(seq, file=ck2file)
        for i in range(naa):
            for j in range(20):
                print('%6.4f' % out[i,j], file=ck2file, end=' ')
            print(file=ck2file)
