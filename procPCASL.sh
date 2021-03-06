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
    $0 <subject> <lifespan | penn>
  "

  exit 1

fi

hcpBaseDir="/data/grossman/hcp"

# Set this here so we don't have to hard code into SetUpHCPPipeline.sh
export HCPPIPEDIR="${hcpBaseDir}/scripts/Pipelines-3.4.0"

hcpPipelineScriptDir="${HCPPIPEDIR}/Examples/Scripts"

source ${hcpPipelineScriptDir}/SetUpHCPPipeline.sh

studyArgs="--StudyFolder=${hcpBaseDir}/subjectsPreProc/ --Subjlist=$1 --runlocal"

if [[ "$2" == "lifespan" ]]; then

  echo "
  Submitting job to Functional pipelines for Lifespan Pilot Phase 1a data
	co - didn't fix this one yet
  "   

elif [[ "$2" == "penn" ]]; then

  echo "
  Submitting job to Functional pipelines for Penn Prisma data
  "

  ${hcpPipelineScriptDir}/GenericPCASLVolumeProcessingPipelineBatch_pennPrisma.sh $studyArgs
  checkExit GenericPCASLVolumeProcessingPipelineBatch $?
  ${hcpPipelineScriptDir}/GenericPCASLSurfaceProcessingPipelineBatch_pennPrisma.sh $studyArgs
  checkExit GenericPCASLSurfaceProcessingPipeline $?


else
  echo " 
  Unrecognized data source : $2
  "
  exit 1
fi



