#!/bin/bash

if [[ $# -eq 0 ]]; then

  echo " 
    $0 <subject> <lifespan|penn>

    Second arg identifies data source:

     lifespan   WashU phase 1a pilot data
     penn       Penn prisma data (default)
  "

  exit 1

fi

hcpBaseDir="/data/grossman/hcp"

scriptDir="${hcpBaseDir}/scripts"

slots=2

subject=$1

# lifespan (WashU) or penn (actually any prisma)
dataType=$2

# Don't overwrite existing output
structuralProcDir="${hcpBaseDir}/subjectsPreProc/${subject}/T1w"

if [[ -d "${structuralProcDir}" ]]; then
  echo " Output already exists in ${structuralProcDir} "
  exit 1
fi

logDir=${hcpBaseDir}/subjectsPreProc/${subject}/logs

if [[ ! -d $logDir ]]; then
  mkdir $logDir
fi

qsub -S /bin/bash -cwd -j y -o "${logDir}/${subject}_StructuralPreProc_\$JOB_ID.stdout" -pe unihost $slots -binding linear:$slots -l h_vmem=16.5G,s_vmem=16G ${scriptDir}/procStructural.sh $subject $dataType

sleep 0.1

