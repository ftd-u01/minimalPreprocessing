#!/bin/bash

hcpBaseDir="/data/grossman/hcp"

if [[ $# -eq 0 ]]; then

  echo " 
    $0 <subject>

    outputs to

    ${hcpBaseDir}/DTI/subject

  "

  exit 1

fi

scriptDir="${hcpBaseDir}/scripts"

slots=2

subject=$1


structuralProcDir="${hcpBaseDir}/subjectsPreProc/${subject}/T1w"

if [[ ! -f "${structuralProcDir}/Diffusion/data.nii.gz" ]]; then
  echo " Cannot find DWI data in ${structuralProcDir}/Diffusion "
  exit 1
fi

outputDir=${hcpBaseDir}/DTI/${subject}

if [[ ! -d $outputDir ]]; then
  mkdir -p $outputDir
fi

qsub -S /bin/bash -wd ${outputDir} -j y -o "${outputDir}/${subject}_dtifit_\$JOB_ID.stdout" -pe unihost $slots -binding linear:$slots -l h_vmem=11G,s_vmem=11G ${scriptDir}/dtifit.sh $subject 

sleep 0.1

