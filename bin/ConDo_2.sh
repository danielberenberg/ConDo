#!/bin/bash 


####################### LOAD MODULES #####################################
module load intel/license
module load intel/compiler/2019-3
module load intel/mkl/2019-3


PRFX="[main]"
###################### PRELUDE #####################################
###### Paths for ConDo.
export CONDO_DIR=/mnt/ceph/users/dberenberg/Nastyomics/DomainPrediction/ConDo
source ${CONDO_DIR}/ConDo.PATH
echo "$PRFX Set all paths and variables."

# error codes
SUCCESS=0
NO_OUTPUT=1
POOR_INPUT=2


#####
SCRIPT="ConDo_2.sh"
####################### INVOCATION   #####################################
usage() {
    echo "Run the ConDo Domain Boundary Prediction pipeline."
    echo "Usage: ${SCRIPT} <fasta> [processors]"
    echo -e "\t[processors] is either specified or defaulted to half of the total available processors."
    echo "------------------------------"
    echo -e "Generates features:"
    echo -e "\tHHSearch  - HMM assisted multiple sequence alignment."
    echo -e "\tCCMpred   - Residue-Residue contact prediction using sequence alignment."
    echo -e "\tBLAST     - Position-specific scoring matrices against UniRef90."
    echo -e "\tSANN      - Solvent accessibility prediction."
    echo -e "\tPSIPRED   - Secondary structure prediction."

    echo "Return codes:"
    echo -e "\t$SUCCESS := SUCCESS, errorless."
    echo -e "\t$NO_OUTPUT := NO_OUTPUT, an expected output was not found."
    echo -e "\t$POOR_INPUT := POOR_INPUT, the input was malformed or nonexistant."
}


###################### Functions     #####################################

_notfound() {
    echo $1 $2 not found. Something may be wrong with $1. Returning $NO_OUTPUT. 
}

run_ccmpred() {
    local prefix="[ccmpred]"

    target=${1%.*} # remove extension 
    if [ $# -eq 1 ]; then
        NPROCESSORS=1
    else
        NPROCESSORS=$2
    fi
    
    nalign=$(cat $target.aln | wc -l)
    echo "$prefix Alignment count: $nalign"

    if [ $nalign -gt 5 ]; then
        if [ ! -s $target.ccmpred ]; then
            echo "$prefix Running ..."
            ${CCMPRED_BIN}/ccmpred $target.aln $target.ccmpred -t ${NPROCESSORS} 
        else
             echo "$prefix Found ${target}.ccmpred. Skipping."
        fi
    else # Quit out if there weren't enough aligned target sequence.
        echo "$prefix Not enough alignments. Exiting with code $POOR_INPUT."
        rm -f $target.ccmpred
        touch $target.ccmpred
        return $POOR_INPUT
    fi

    if [ ! -e $target.ccmpred ]; then
        _notfound $prefix $target.ccmpred
        return $NO_OUTPUT
    fi

    return $SUCCESS
}

run_alignment() {
    # Runs the alignment step of ConDo. Replaces JACKHMMER with HHBLITS
    prefix="[alignment]"

    local KEY=${1%.*} # remove extension 

    if [ $# -eq 1 ]; then
        NPROCESSORS=1
    else
        NPROCESSORS=$2
    fi

    if [[ -s ${KEY}.fasta && -s ${KEY}.hhr && -s ${KEY}.a3m ]] ; then
        echo "${prefix} Skipping alignment, files exist and are not empty"
    else
        echo "${prefix} Generating alignment..."
        ${HHPATH}/bin/hhblits -i ${KEY}.fasta -d ${CAFA4_DATABASE} -o ${KEY}.hhr -oa3m ${KEY}.a3m -e 0.01 -n 3 -cpu 1 -diff inf -cov 10 -Z 10000 -B 10000 
    fi
    
    ${HHPATH}/scripts/reformat.pl a3m sto ${KEY}.a3m ${KEY}.align       # Generates .align file. Alignment in Stockholm format. 
    ${HHPATH}/scripts/reformat.pl a3m a2m ${KEY}.a3m ${KEY}.a2m         # Generates .a2m file. Only difference is that gaps aligned to inserts may be omitted.
    ${HHPATH}/scripts/reformat.pl -r ${KEY}.a2m ${KEY}.hmm.fas          # Generates .hmm.fas file. Removes lowercase residues.

    ${PY3} ${CONDO_BIN}/aln.py ${KEY} # Generates a .aln file. (Removes all headers information from a2m file to generate one large alignment mat.
    
    if [ ! -s ${KEY}.aln ]; then
        _notfound ${prefix} ${KEY}.aln
        return $NO_OUTPUT
    fi

    return ${SUCCESS}
}


run_blast() {
    local prefix="[blast]"

    target=${1%.*} # remove extension 
    if [ $# -eq 1 ]; then
        NPROCESSORS=1
    else
        NPROCESSORS=$2
    fi

    if [ ! -s "${target}.chk" ]; then  # run BLAST
        ${BLAST_BIN}/blastpgp -b 0 -v 5000 -j 3 -h 0.001 -a ${NPROCESSORS} -d ${UNIREF90} -i $target.fasta -C $target.chk
    else
        echo "${target}.chk file found. Skipping BLAST."
    fi

    if [ ! -e $target.chk ]; then
        _notfound $prefix $target.chk
        return $NO_OUTPUT
    fi

    return $SUCCESS

}

run_psipred(){
    local prefix="[psipred]"

    target=${1%.*} # remove extension 

    local psi=$(dirname $target)/psipred
    local base=$(basename ${target})

    mkdir -p ${psi}
    if [ ! -s ${psi}/${base}.mtx ]; then
        echo "$prefix Running seq2mtx ..."
        ${PSIPRED_BIN}/seq2mtx ${target}.fasta > ${psi}/${base}.mtx
    else
        echo "$prefix ${psi}/${base}.mtx found. Skipping seq2mtx."
    fi

    if [ ! -s ${target}.ss ]; then
        echo "$prefix Running psipred ..."
        ${PSIPRED_BIN}/psipred ${psi}/${base}.mtx ${PSIPRED_DATA}/weights.dat ${PSIPRED_DATA}/weights.dat2 ${PSIPRED_DATA}/weights.dat3 > ${target}.ss
    else
        echo ${target}.ss found. Skipping psipred.
    fi

    if [ ! -s ${target}.horiz ]; then
        echo "$prefix Running psipass2 ..."
        ${PSIPRED_BIN}/psipass2 ${PSIPRED_DATA}/weights_p2.dat 1 1.0 1.0 ${target}.ss2 ${target}.ss > ${target}.horiz
    else
        echo ${target}.horiz found. Skipping psipass2.
    fi

    if [ ! -e $target.ss2 ]; then
        _notfound $prefix $target.ss2
        return $NO_OUTPUT
    fi

    return $SUCCESS

}

run_sann() {
    local prefix="[sann]"

    target=${1%.*} # remove extension 
    if [ $# -eq 1 ]; then
        NPROCESSORS=1
    else
        NPROCESSORS=$2
    fi
    
    if [[ ! -s $target.a22 && ! -s $target.a3 ]]; then
        echo "$prefix Running mkchk2."
        LOG=$(dirname $target)/gen_features.log
        ${MKCHK2} ${target} --qij ${CONDO_DATA}/qij | tee -a ${LOG}
        echo "$prefix Running sann.sh"
        ${SANN}/bin/sann.sh ${target}.fasta ${NPROCESSORS}
    else
        echo "$prefix Found $target.a22 and $target.a3. Skipping this step."
    fi
    
    if [ ! -e $target.a22 ]; then
        _notfound $prefix $target.a22
        return $NO_OUTPUT
    fi

    if [ ! -e $target.a3 ]; then
        _notfound $prefix $target.a3
        return $NO_OUTPUT
    fi

    #ln -s ${target}.a3 ${target}.sa2

    return $SUCCESS
}

run_feature() {
    local prefix="[feature]"

    target=${1%.*} # remove extension 
    if [ $# -eq 1 ]; then
        NPROCESSORS=1
    else
        NPROCESSORS=$2
    fi
    # /path/to/data/prefix
    ${CONDO_BIN}/feature $target ${NPROCESSORS}
    if [ ! -e $target".feature.txt" ]; then
        _notfound $prefix "${target}_feature.txt"
        return $NO_OUTPUT
    fi

    return $SUCCESS
}


###################### Command line processing #####################################
TARGET_FASTA=$1
TARGET_BASENAME=${1%.*}
target=${TARGET_BASENAME}

if [ $# -eq 1 ]; then
    np=$(nproc --all)
    NPROCESSORS=$(($np / 2 ))
else
    NPROCESSORS=$2
fi

if [ ! -e "${TARGET_FASTA}" ]; then
    echo "$PRFX ${TARGET_FASTA} not found." 
    usage
    exit $POOR_INPUT
fi

echo "$PRFX fasta=$TARGET_FASTA, threads=$NPROCESSORS"

##################################################################################
#////////\\\\\\\\////////\\\\\\\\////////\\\\\\\\////////\\\\\\\\////////\\\\\\\\#
#///////  \\\\\\\///////  \\\\\\\///////  \\\\\\\///////  \\\\\\\///////  \\\\\\\#
#//////    \\\\\\//////    \\\\\\//////    \\\\\\//////    \\\\\\//////    \\\\\\#
#/////      \\\\\/////      \\\\\/////      \\\\\/////      \\\\\/////      \\\\\#
#////        \\\\////        \\\\////        \\\\////        \\\\////        \\\\#
#///          \\\///          \\\///          \\\///          \\\///          \\\#
#// generating \\//  features  \\//    from    \\//  external  \\//  programs! \\#
#\\            //\\            //\\            //\\            //\\            //#
#\\\          ///\\\          ///\\\          ///\\\          ///\\\          ///#
#\\\\        ////\\\\        ////\\\\        ////\\\\        ////\\\\        ////#
#\\\\\      /////\\\\\      /////\\\\\      /////\\\\\      /////\\\\\      /////#
#\\\\\\    //////\\\\\\    //////\\\\\\    //////\\\\\\    //////\\\\\\    //////#
#\\\\\\\  ///////\\\\\\\  ///////\\\\\\\  ///////\\\\\\\  ///////\\\\\\\  ///////#
#\\\\\\\\////////\\\\\\\\////////\\\\\\\\////////\\\\\\\\////////\\\\\\\\////////#
##################################################################################

echo "$PRFX Starting hhblits."
run_alignment $target ${NPROCESSORS}
if [ $? -gt $SUCCESS ]; then 
    exit $?
fi

echo "$PRFX Starting ccmpred."
run_ccmpred $target ${NPROCESSORS}
if [ $? -gt $SUCCESS ]; then
    exit $?
fi

echo "$PRFX Starting blast."
run_blast $target ${NPROCESSORS} 
if [ $? -gt $SUCCESS ]; then
    exit $?
fi

echo "$PRFX Starting psipred."
run_psipred $target 
if [ $? -gt $SUCCESS ]; then
    exit $?
fi

echo "$PRFX Starting sann."
run_sann $target ${NPROCESSORS}
if [ $? -gt $SUCCESS ]; then
    exit $?
fi

############### run prediction
module unload intel/compiler/2019-3 intel/mkl/2019-3

# for TensorFlow

run_feature $target ${NPROCESSORS}
if [ $? -gt $SUCCESS ]; then
    exit $?
fi

CONF_CUT=1.4

# make prediction
${CONDO_BIN}/condo-helper-suite run $(dirname ${target})

#${PY3} ${CONDO_BIN}/gather_input.py ${target}
#${PY3} ${CONDO_BIN}/prediction.py data_feature.dat.npz y_pred.dat.npz ${WEIGHT_FILE}
#${PY3} ${CONDO_BIN}/gen_results.py ${target} ${CONF_CUT}

