#!/usr/bin/env bash


prefix="[uniclust-shm-setup]"
# if we are on the BNL nodes, grab the DB fom the BNL GPFS drives rather than ceph
if [[ ${SLURM_JOB_PARTITION} == "bnl" ]] ; then
    DB_DSK_PATH=/mnt/bnlgpfs/renfrew/MicrobiomeImmunityProject2/Databases
else
    #DB_DSK_PATH=/mnt/ceph/users/renfrew/MicrobiomeImmunityProject2/Databases
    DB_DSK_PATH=${UNICLUST_DSK}
fi

export DB_SHM_PATH=/dev/shm/dberenberg/condo/Databases
echo "$prefix DB_SHM_PATH=${DB_SHM_PATH}"

# make a dir n the shared memory on each node
if [ ! -e ${DB_SHM_PATH} ]; then
    mkdir -p ${DB_SHM_PATH}
    
    # Load the uniclust databases into the shared memory drive on each node.
    echo $prefix Copying ${DB_DSK_PATH}/${UNICLUST_VERSION} to ${DB_SHM_PATH}.
    cp -arp ${DB_DSK_PATH}/${UNICLUST_VERSION} ${DB_SHM_PATH}/
else
    echo $prefix ${DB_SHM_PATH} exists!
fi

echo $prefix Done.
