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

slots=3

# Don't overwrite existing output
diffusionProcDir="${hcpBaseDir}/subjectsPreProc/${subject}/Diffusion"

if [[ -d "${diffusionProcDir}" ]]; then
  echo " Output already exists in ${diffusionProcDir} "
  exit 1
fi

# Check for unprocessed diffusion data
diffusionDataDir="${hcpBaseDir}/subjectsPreProc/${subject}/unprocessed/3T/Diffusion"

if [[ ! -d "${diffusionDataDir}" ]]; then
  echo " No diffusion data for $subject in $diffusionDataDir"
  exit 1
fi

# Should be created by structural script
logDir=${hcpBaseDir}/subjectsPreProc/${subject}/logs

qsub -S /bin/bash -cwd -j y -o "${logDir}/${subject}_DiffusionPreProc_\$JOB_ID.stdout" -pe unihost $slots -binding linear:$slots -l h_vmem=17G,s_vmem=16G ${scriptDir}/procDiffusion.sh $subject $dataType

sleep 0.1

