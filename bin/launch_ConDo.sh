#!/usr/bin/env bash

#SBATCH --job-name=ConDo 
#SBATCH --output=ConDo.out
#SBATCH --error=ConDo.err

#
# Launch ConDo!
#   

. /etc/profile.d/modules.sh

module load slurm
module load disBatch/1.4

# print slurm enviromnet
env | sort | grep SLURM

# if we are on the BNL nodes, grab the DB fom the BNL GPFS drives rather than ceph
if [[ ${SLURM_JOB_PARTITION} == "bnl" ]] ; then
    DB_DSK_PATH=/mnt/bnlgpfs/renfrew/MicrobiomeImmunityProject2/Databases
else
    DB_DSK_PATH=/mnt/ceph/users/renfrew/MicrobiomeImmunityProject2/Databases
fi

export DB_SHM_PATH=/dev/shm/${SLURM_JOB_USER}/${SLURM_JOB_ID}/Databases

# make a dir n the shared memory on each node
srun mkdir -p ${DB_SHM_PATH}

# Load the uniclust databases into the shared memory drive on each node.
srun cp -arp ${DB_DSK_PATH}/uniclust30_2018_08 ${DB_SHM_PATH}/

srun tree /dev/shm/

# Enter the working directory.
cd /mnt/ceph/users/dberenberg/Nastyomics/DomainPrediction/ConDo

# Run all the tasks.
disBatch.py -c 10 ConDoTestTasks
