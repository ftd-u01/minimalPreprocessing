#!/bin/bash

checkExit() {

  pipelineName=$1
  exCode=$2

  if [[ $exCode -ne 0 ]]; then
    echo "

  $pipelineName exited with code $exCode
  
" 
    exit 1
  fi

}

if [[ $# -eq 0 ]]; then

  echo " 
    $0 <subject> [lifespan|penn]
  "

  exit 1

fi

hcpBaseDir="/data/grossman/hcp"

subject=$1

# Set this here so we don't have to hard code into SetUpHCPPipeline.sh
export HCPPIPEDIR="${hcpBaseDir}/scripts/Pipelines-3.4.0"

hcpPipelineScriptDir="${HCPPIPEDIR}/Examples/Scripts"

source ${hcpPipelineScriptDir}/SetUpHCPPipeline.sh

studyArgs="--StudyFolder=${hcpBaseDir}/subjectsPreProc/ --Subjlist=$subject --runlocal"

dataSource="penn"

if [[ $# -gt 1 ]]; then
  dataSource=$2
fi

if [[ $dataSource == "lifespan" ]]; then

  echo "
  Submitting job to Diffusion pipeline for Lifespan Pilot Phase 1a data
  "   

  ${hcpPipelineScriptDir}/DiffusionPreprocessingBatch_lifespanPilotData.sh $studyArgs
  checkExit DiffusionPreprocessing $?

elif [[ $dataSource == "penn" ]]; then

  echo "
  Submitting job to Diffusion pipeline for Penn Prisma data
  "

  ${hcpPipelineScriptDir}/DiffusionPreprocessingBatch_pennPrisma.sh $studyArgs
  checkExit DiffusionPreprocessing $?

else
  echo " 
  Unrecognized data source : $dataSource
  "
  exit 1
fi

## Clean up Diffusion directory to save disk space
## Can delete the whole thing but save about 50% of space by getting rid of intermediate
## files only, keeps corrected data in native space and warps
# for dir in eddy rawData; do
#  rm -rf ${hcpBaseDir}/subjectsPreProc/${subject}/Diffusion/${dir}
# done

# short on disk space, so clean up more aggressively
# Leave diffusion Dir itself to signal that the processing is done
rm -rf ${hcpBaseDir}/subjectsPreProc/${subject}/Diffusion/*

echo "Diffusion pre-processing completed at `date`" > ${hcpBaseDir}/subjectsPreProc/${subject}/Diffusion/diffusionPreProcessingCompleted.txt
