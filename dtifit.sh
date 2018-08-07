#!/bin/bash

if [[ $# -eq 0 ]]; then
  echo " $0 <subject> "
  exit 1
fi

subject=$1

binDir=`dirname $0`

baseDir=/data/grossman/hcp/

outDir=${baseDir}/DTI/${subject}

if [[ -d $outputDir ]]; then
  echo " Output exists for $subject "
  exit 1
fi

antsPath=${baseDir}/bin/ants/
caminoPath=${baseDir}/bin/camino/bin

mkdir -p $outDir

# Use DTI aligned to T1 space

export CAMINO_HEAP_SIZE=8192

if [[ -z "$TMPDIR" ]]; then
  TMPDIR=/tmp
fi

t1InputDir=${baseDir}/subjectsPreProc/${subject}/T1w
dwiInputDir=${t1InputDir}/Diffusion

scheme=${TMPDIR}/${subject}Diffusion.scheme

echo "
--- `date`   Extracting inner shell for DTI ---"

${caminoPath}/fsl2scheme -bvals ${dwiInputDir}/bvals -bvecs ${dwiInputDir}/bvecs -bscale 1 -outputfile $scheme
${caminoPath}/selectshells -inputfile ${dwiInputDir}/data.nii.gz -schemefile $scheme -maxbval 1800 -outputroot ${outDir}/data_b1500_shell 
${caminoPath}/scheme2fsl -inputfile ${outDir}/data_b1500_shell.scheme -bscale 1 -outputroot ${outDir}/data_b1500_shell

export HCPPIPEDIR=${baseDir}/scripts/Pipelines-3.4.0

source ${baseDir}/scripts/Pipelines-3.4.0/Examples/Scripts/SetUpHCPPipeline.sh

echo "
--- `date`   DTI fit ---"

dtifit --data=${outDir}/data_b1500_shell.nii.gz \
  --out=${outDir}/${subject} \
  --mask=${dwiInputDir}/nodif_brain_mask.nii.gz \
  --bvecs=${outDir}/data_b1500_shell.bvecs \
  --bvals=${outDir}/data_b1500_shell.bvals \
  --wls --save_tensor

# Warp labels to DTI space
echo "
--- `date`   Resampling labels and T1 ---"

dtAlignedT1=${t1InputDir}/T1w_acpc_dc_restore_1.50.nii.gz

for labels in aparc.a2009s+aseg.nii.gz aparc+aseg.nii.gz wmparc.nii.gz; do 

  ${antsPath}/antsApplyTransforms -d 3 -i ${t1InputDir}/$labels -r ${dtAlignedT1} -n NearestNeighbor -o ${outDir}/${subject}_${labels}

  cp $dtAlignedT1 ${outDir}/${subject}_T1w_resampled.nii.gz

done

echo "
--- `date`   Warping scalars to MNI ---"

${binDir}/warpDTIToMNI.sh ${subject}
