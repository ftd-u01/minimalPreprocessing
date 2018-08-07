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
    $0 <subject> [penn|lifespan]
  "

  exit 1

fi

hcpBaseDir="/data/grossman/hcp"

# Set this here so we don't have to hard code into SetUpHCPPipeline.sh
export HCPPIPEDIR="${hcpBaseDir}/scripts/Pipelines-3.4.0"

hcpPipelineScriptDir="${HCPPIPEDIR}/Examples/Scripts"

source ${hcpPipelineScriptDir}/SetUpHCPPipeline.sh

studyArgs="--StudyFolder=${hcpBaseDir}/subjectsPreProc/ --Subjlist=$1 --runlocal"

dataSource="penn"

if [[ $# -gt 1 ]]; then
  dataSource=$2
fi

if [[ $dataSource == "lifespan" ]]; then

  echo "
  Submitting job to PreFreeSurfer pipeline for Lifespan Pilot Phase 1a data
  "   

  ${hcpPipelineScriptDir}/PreFreeSurferPipelineBatch_lifespanPilotData.sh $studyArgs
  checkExit PreFreeSurferPipeline $?

elif [[ $dataSource == "penn" ]]; then

  echo "
  Submitting job to PreFreeSurfer pipeline for Penn Prisma data
  "

  ${hcpPipelineScriptDir}/PreFreeSurferPipelineBatch_pennPrisma.sh $studyArgs
  checkExit PreFreeSurferPipeline $?

else
  echo " 
  Unrecognized data source : $dataSource
  "
  exit 1
fi

${hcpPipelineScriptDir}/FreeSurferPipelineBatch.sh $studyArgs
checkExit FreeSurferPipeline $?

${hcpPipelineScriptDir}/PostFreeSurferPipelineBatch.sh $studyArgs
checkExit PostFreeSurferPipeline $?

