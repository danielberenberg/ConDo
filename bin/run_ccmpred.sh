#!/bin/bash

ccmpredbindir=/mnt/ceph/users/dberenberg/Nastyomics/DomainPrediction/ConDo/CCMpred/bin

target=$1

if [ $# -eq 1 ]
then
    nprocessor=1
else
    nprocessor=$2
fi

nalign=`cat $target.aln |wc -l`
echo "Number of alignments: $nalign"

if [ $nalign -gt 5 ]; then
    if [ ! -s $target.ccmpred ]; then
        echo "Running CCMpred..."
        $ccmpredbindir/ccmpred $target.aln $target.ccmpred -t $nprocessor > ccmpred.log
    fi
else # Quit out if there weren't enough aligned target sequence.
    rm -f $target.ccmpred
    touch $target.ccmpred
fi


