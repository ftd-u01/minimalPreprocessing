#!/bin/bash

if [[ $# -eq 0 ]]; then

  echo " 
    $0 <subject> 
  "

  exit 1

fi

hcpBaseDir="/data/grossman/hcp"

scriptDir="${hcpBaseDir}/scripts"

logDir="${hcpBaseDir}/logs"

slots=1

qsub -b y -cwd -j y -o ${logDir}/${1}_fitTensor.stdout -pe unihost $slots -binding linear:$slots -l h_vmem=8.1G,s_vmem=8G ${scriptDir}/dtifit.sh $1 
sleep 0.1

