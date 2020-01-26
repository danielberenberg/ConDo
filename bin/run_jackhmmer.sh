#!/bin/bash 

# set directory and file path
module load intel/license
module load intel/compiler/2019-3
module load intel/mkl/2019-3

HH_INTEL=/mnt/ceph/users/mip/Programs/hh-suite/hh-suite/build_intel/
UNIREF90=/mnt/ceph/users/protfold/FFPred/FFPred/uniref90/data/uniref90.fasta
UNIREF90=/dev/shm/dberenberg/Databases/uniref90.fasta

hhpath=${HH_INTEL}

condodir=/mnt/ceph/users/dberenberg/Nastyomics/DomainPrediction/ConDo
condobin=$condodir/bin
database=${UNIREF90}

jackhmmerbin=$condodir/hmmer-3.2.1/bin

export HHLIB=$hhpath

target=${1%.*}

if [ $# -eq 1 ]
then
    nprocessor=1
else
    nprocessor=$2
fi

echo "hammering ... $nprocessor procs."
$jackhmmerbin/jackhmmer -N 4 --cpu $nprocessor -o $target.dat -A $target.align $target.fasta $database 
echo "reformatting ..."
$jackhmmerbin/esl-reformat -o $target.a2m a2m $target.align
echo "hh reformatting ..."
$hhpath/scripts/reformat.pl -r $target.a2m $target.hmm.fas
$condobin/jackhammer_aln.py $target
$condobin/jackhammer_si.py $target

rm -f $target.align $target.a2m $target.hmm.fas 

