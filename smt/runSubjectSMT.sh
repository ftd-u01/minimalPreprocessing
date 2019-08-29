#!/bin/bash

hcpBaseDir="/data/grossman/hcp"

if [[ $# -eq 0 ]]; then

    echo " 
  $0 <subject_scan>

  outputs to

  ${hcpBaseDir}/smt/subject_scan

"
    
    exit 1

fi

scriptDir="${hcpBaseDir}/scripts/smt"

slots=1

scan=$1

structuralProcDir="${hcpBaseDir}/subjectsPreProc/${scan}/T1w"

if [[ ! -f "${structuralProcDir}/Diffusion/data.nii.gz" ]]; then
    echo " Cannot find DWI data in ${structuralProcDir}/Diffusion "
    exit 1
fi

dtiProcDir="${hcpBaseDir}/DTI/${scan}"

if [[ ! -f "${dtiProcDir}/${scan}_aparc+aseg.nii.gz" ]]; then
    echo " Cannot find DWI data in ${dtiProcDir} "
    exit 1
fi

outputDir=${hcpBaseDir}/smt/${scan}

if [[ ! -d $outputDir ]]; then
    mkdir -p $outputDir

    qsub -S /bin/bash -wd ${outputDir} -j y -o "${outputDir}/smtGaussian_\$JOB_ID.stdout" -pe unihost $slots -binding linear:$slots -l h_vmem=6G,s_vmem=6G ${scriptDir}/smtGaussian.sh $scan

    sleep 0.1

    qsub -S /bin/bash -wd ${outputDir} -j y -o "${outputDir}/smtRician_\$JOB_ID.stdout" -pe unihost $slots -binding linear:$slots -l h_vmem=6G,s_vmem=6G ${scriptDir}/smtRician.sh $scan

    sleep 0.1
else
    echo " Output dir $outputDir already exists "
    exit 1
fi
