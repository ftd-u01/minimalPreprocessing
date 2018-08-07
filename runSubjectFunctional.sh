#!/bin/bash

if [[ $# -eq 0 ]]; then

  echo " 
    $0 <subject> <lifespan|penn>

    Second arg identifies data source:

     lifespan   WashU phase 1a pilot data
     penn       Penn prisma data
  "

  exit 1

fi

hcpBaseDir="/data/grossman/hcp"

scriptDir="${hcpBaseDir}/scripts"

subject=$1

# lifespan (WashU) or penn (actually any prisma)
dataType=$2

slots=2

# Should be created by structural script
logDir=${hcpBaseDir}/subjectsPreProc/${subject}/logs

qsub -S /bin/bash -cwd -j y -o "${logDir}/${subject}_FunctionalPreProc_\$JOB_ID.stdout" -pe unihost $slots -binding linear:$slots -l h_vmem=16.5G,s_vmem=16G ${scriptDir}/procFunctional.sh $subject $dataType

sleep 0.1

