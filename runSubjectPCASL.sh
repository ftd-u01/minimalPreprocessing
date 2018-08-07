#!/bin/bash

if [[ $# -eq 0 ]]; then

  echo " 
    $0 <subject> <lifespan|penn>

    Second arg identifies data source:

     lifespan   WashU phase 1a pilot data
     penn       Penn prisma data

    qsubs procPCASL.sh

  "

  exit 1

fi

hcpBaseDir="/data/grossman/hcp"

scriptDir="${hcpBaseDir}/scripts"

logDir="${hcpBaseDir}/logs"

slots=1

qsub -S /bin/bash -cwd -j y -o ${logDir}/${1}_PCASLPreProc.stdout -pe unihost $slots -binding linear:$slots -l h_vmem=12.5G,s_vmem=12G ${scriptDir}/procPCASL.sh $1 $2

sleep 0.1

