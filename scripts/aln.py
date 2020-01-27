#!/usr/bin/env python

from itertools import groupby
import numpy as np
import sys

USAGE="""
aln.py target
Generates an aln file from 
"""

seqcode1="ARNDCQEGHILKMFPSTWYV-"

def parse_sequence_from_fasta(fastafile):
    """Retrieve the sequence from a single sequence fasta file."""
    with open(fastafile, 'r') as fp:
        _ = next(fp)
        sequence = ''.join(line.strip() for line in fp)
    return sequence
        

def parse_alignment_file(query_sequence, filename):
    """Parse an alignment file aligned to `query_sequence`.

    Parsing entails retrieving the aligned sequence title, the alignment lines, the initial gap placement
    and the final gap placement
    """
    N = len(query_sequence)
    with open(filename, 'r') as handle:
        for i, (is_header, group) in enumerate(groupby(handle, key=lambda line: line.startswith('>'))):
            if is_header:
                title = group.__next__().lstrip('>').rstrip()
            else:
                seq    = ''.join(line.strip() for line in group)
                if len(seq) == N:
                    is_not_gap = list(filter(lambda i: seq[i] != '-', range(len(seq))))
                    if is_not_gap: # non empty
                        ini = min(is_not_gap)
                        fin = max(is_not_gap)
                    else:
                        ini, fin = 0, N - 1
                    yield [title, seq, ini, fin]
                else:
                    print(len(seq), '!=', N, '!')

def main():
    try:
        target = sys.argv[1]
    except IndexError:
        print(USAGE)
        sys.exit()

    a2mfile = target + ".hmm.fas"
    fasta   = target + ".fasta"

    seq = parse_sequence_from_fasta(fasta)
    aln = list(parse_alignment_file(seq, a2mfile))
    Nseq, Naln = map(len, (seq, aln))
    
    _, alignments, _, _ = zip(*aln)
    with open(target + '.aln', 'w') as alnfile:
        print(*alignments, sep='\n', file=alnfile)

    with open(target + '.msa', 'w') as msafile:
        for h, a, ini, fin in aln:
            print(f">{h.split()[0]}/{ini}-{fin}", file=msafile)
            print(a, file=msafile)

    print(f"[aln]: Wrote {target}.aln and {target}.msa.")
    
    #old_title = ""
    #aln2 = []
    #check = False
    #for i, item in enumerate(aln):
    #    title, alignment, ini, fin = item 
    #    if title != old_title:
    #        if check:
    #            #print("Appending to aln2")
    #            aln2.append(con)
    #        con = item
    #        check = True
    #        old_title = title
    #    else:
    #        #print("appending...")
    #        con.append(item)
    #aln2 += con
    #print(len(aln2), len(aln))

        
    #aln2=[]
    #k=0
    #title_old=""
    #check=0

    #for i in range(0,Naln) :
    #    title=aln[i][0]
    #    seq=aln[i][1]
    #    ini1=aln[i][2]
    #    fin1=aln[i][3]

    #    if title!=title_old:
    #        if check!=0:
    #            aln2+=[con]
    #        check=1
    #        k+=1
    #        title_old=title
    #        con=[aln[i]]
    #    else:
    #        con+=[aln[i]]
    #aln2+=[con]

    #alnfile=target+".aln"
    #fp_aln=open(alnfile,"w")

    #msafile=target+".msa"
    #fp_msa=open(msafile,"w")

    #Naln2=len(aln2)
    #for k in range(0,Naln2) :
    #    dom=aln2[k]
    #    Ndom=len(dom)
    #    title= dom[0][0]
    #    if Ndom==1 :
    #        seq= dom[0][1]
    #        ini1=dom[0][2]
    #        fin1=dom[0][3]

    #        print >>fp_msa, "%s/%d-%d" %(title, ini1+1, fin1+1)
    #        print >>fp_msa, seq
    #        print >>fp_aln, seq
    #        continue
    #    check_use=[]
    #    for m in range(0,Ndom):
    #        check_use+=[0]
    #    for m in range(0,Ndom):
    #        dm=dom[m]
    #        seq1=dm[1]
    #        ini1=dm[2]
    #        fin1=dm[3]
    #        for n in range(m+1,Ndom):
    #            dn=dom[n]
    #            seq2=dn[1]
    #            ini2=dn[2]
    #            fin2=dn[3]
    #            if (ini1<ini2 and fin1<ini2):
    #                seq_new=seq1[0:ini2]+seq2[ini2:]
    #                if(ini2-fin1>25):
    #                    print >>fp_msa, "%s/%d-%d,%d-%d" %(title, ini1+1, fin1+1,ini2+1,fin2+1)
    #                else :
    #                    print >>fp_msa, "%s/%d-%d" %(title, ini1+1, fin2+1)
    #                print >>fp_msa, seq_new
    #                print >>fp_aln, seq_new
    #                check_use[m]=1
    #                check_use[n]=1

    #            elif (ini1>ini2 and fin2<ini1):
    #                seq_new=seq2[0:ini1]+seq1[ini1:]
    #                if(ini1-fin2>25):
    #                    print >>fp_msa, "%s/%d-%d,%d-%d" %(title, ini2+1, fin2+1,ini1+1,fin1+1)
    #                else :
    #                    print >>fp_msa, "%s/%d-%d" %(title, ini2+1, fin1+1)
    #                print >>fp_msa, seq_new
    #                print >>fp_aln, seq_new
    #                check_use[m]=1
    #                check_use[n]=1
    #        if (check_use[m]==0):
    #            print >>fp_msa, "%s/%d-%d" %(title, ini1+1, fin1+1)
    #            print >>fp_msa, seq1
    #            print >>fp_aln, seq1

    #fp_aln.close()
    #fp_msa.close()

if __name__ == '__main__':
    main()


