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
  Submitting job to Functional pipelines for Lifespan Pilot Phase 1a data
  "   

  ${hcpPipelineScriptDir}/GenericfMRIVolumeProcessingPipelineBatch_lifespanPilotData.sh $studyArgs
  checkExit GenericfMRIVolumeProcessingPipeline $?


  ${hcpPipelineScriptDir}/GenericfMRISurfaceProcessingPipelineBatch_lifespanPilotData.sh $studyArgs
  checkExit GenericfMRISurfaceProcessingPipeline $?

elif [[ $dataSource == "penn" ]]; then

  echo "
  Submitting job to Functional pipelines for Penn Prisma data
  "

  ${hcpPipelineScriptDir}/GenericfMRIVolumeProcessingPipelineBatch_pennPrisma.sh $studyArgs
  checkExit GenericfMRIVolumeProcessingPipeline $?

  ${hcpPipelineScriptDir}/GenericfMRISurfaceProcessingPipelineBatch_pennPrisma.sh $studyArgs
  checkExit GenericfMRISurfaceProcessingPipeline $?

else
  echo " 
  Unrecognized data source : $dataSource
  "
  exit 1
fi

## This saves about 50% of the space taken up by these dirs
# for task in "rfMRI_REST1_AP rfMRI_REST1_PA rfMRI_REST2_AP rfMRI_REST2_PA tfMRI_GAMBLING_AP tfMRI_GAMBLING_PA tfMRI_WM_AP tfMRI_WM_PA"; do 
#   rm -rf ${hcpBaseDir}/subjectsPreProc/${subject}/${task}/MotionMatrices
# done

# Low on space so clean up more aggressively, results in MNINonLinear directory
# Leave directory so that we can tell results have been processed
for task in "rfMRI_REST1_AP rfMRI_REST1_PA rfMRI_REST2_AP rfMRI_REST2_PA tfMRI_GAMBLING_AP tfMRI_GAMBLING_PA tfMRI_WM_AP tfMRI_WM_PA"; do 
  taskDir="${hcpBaseDir}/subjectsPreProc/${subject}/${task}/"
  if [[ -d "$taskDir" ]]; then
    rm -rf ${taskDir}/*
    echo "fmri processing completed at `date`" > ${taskDir}/functionalPreProcessingCompleted.txt
  fi
done
