#!/bin/bash 


####################### LOAD MODULES #####################################
module load intel/license
module load intel/compiler/2019-3
module load intel/mkl/2019-3

###################### PRELUDE #####################################
##### Extra paths
HH_INTEL=/mnt/ceph/users/mip/Programs/hh-suite/hh-suite/build_intel/
UNIREF90=/mnt/ceph/users/protfold/FFPred/FFPred/uniref90/data/uniref90.fasta

##### Paths for ConDo. (bin/ConDo.sh)
CONDO_DIR=/mnt/ceph/users/dberenberg/Nastyomics/DomainPrediction/ConDo

##### Paths for JackHMMR (bin/run_jackhmmr.sh)
HHPATH=${HH_INTEL}
DATABASE=${UNIREF90}
JACKHMMR_BIN=${CONDO_DIR}/hmmer-3.2.1/bin

##### Paths for gen_features (bin/gen_features.sh)
BLAST_BIN=${CONDO_DIR}/blast/bin
DBNAME=${UNIREF90}
PSIPRED=${CONDO_DIR}/psipred
SANN=${CONDO_DIR}/sann
NNDB_HOME=${SANN}/nndb

##### Paths for CCMpred (bin/run_ccmpred.sh)
CCMPRED_BIN=${CONDO_DIR}/CCMpred/bin

####################### INVOCATION   #####################################
usage() {
    echo "Domain Boundary prediction using ConDo"
    echo "Usage: $0 <fasta> [processors]"
}

###################### Functions     #####################################

run_ccmpred() {
    target=$1

    if [ $# -eq 1 ]; then
        nprocessor=1
    else
        nprocessor=$2
    fi

    nalign=`cat $target.aln | wc -l`
    echo "[ccmpred] Number of alignments: $nalign"
    if [ $nalign -gt 5 ]; then
        if [ ! -s $target.ccmpred ]; then
            echo "[ccmpred] Running ..."
        $ccmpredbindir/ccmpred $target.aln $target.ccmpred -t $nprocessor > ccmpred.log
        fi
    else # Quit out if there weren't enough aligned target sequence.
        echo "[ccmpred] Not enough alignments"
        rm -f $target.ccmpred
        touch $target.ccmpred
    fi
}



condodir=${CONDO_DIR}
condobin=$condodir/bin
weight_file=$condodir/data/weight.h5
target=${1%.*}

echo "Paths set"

if [ $# -eq 1 ]
then
    nprocessor=1
else
    nprocessor=$2
fi

if [ ! -e $target.fasta ]; then
    echo ">>$target.fasta is not exist " 
    exit
fi


if [ ! -s $target.aln ]; then
    echo "Running jackhmmer on $nprocessor processors."
    $condobin/run_jackhmmer.sh $target $nprocessor
    if [ ! -e $target.aln ]; then
        echo ">> $target.aln does not exist after running jackhmmer ..."
    fi
fi

echo "running ccmpred"
$condobin/run_ccmpred.sh $target $nprocessor
echo "running gen_features"
$condobin/gen_features.sh $target $nprocessor
if [ ! -e $target.ss2 ]; then
    echo ">>$target.ss2 is not exist " 
    echo ">>check PSIPRED"
    exit
fi
if [ ! -e $target.a22 ]; then
    echo ">>$target.a22 is not exist "
    echo ">>check SANN"
    exit
fi
if [ ! -e $target.a3 ]; then
    echo ">>$target.a3 is not exist "
    echo ">>check SANN"
    exit
fi
if [ ! -e $target.msa ]; then
    echo ">>$target.msa is not exist "
    echo ">>check jackhammer"
    exit
fi
if [ ! -e $target.ccmpred ]; then
    echo ">>$target.ccmpred is not exist "
    echo ">>check ccmpred"
    exit
fi

$condobin/feature $target $nprocessor
if [ ! -e $target"_feature.txt" ]; then
    echo ">>$target"_feature.txt" is not exist "
    echo ">>check feature "
    exit
fi

$condobin/gather_input.py $target
#keras with TF or theano (CPU)
$condobin/prediction.py data_feature.dat.npz y_pred.dat.npz $weight_file
target=${TARGET_BASENAME}
# GPU for theano
#THEANO_FLAGS=device=cuda,floatX=float32, python $condobin/prediction.py data_feature.dat.npz y_pred.dat.npz $weight_file

conf_cut=1.4
$condobin/gen_results.py $target $conf_cut

