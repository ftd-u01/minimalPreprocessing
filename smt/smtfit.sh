#!/bin/bash

if [[ $# -eq 0 ]]; then
  echo " $0 <subject> "
  exit 1
fi

subject=$1

baseDir=/data/grossman/hcp/

outputDir=${baseDir}/smt/${subject}

mkdir -p $outputDir

t1InputDir=${baseDir}/subjectsPreProc/${subject}/T1w
dwiInputDir=${t1InputDir}/Diffusion

bvals=${dwiInputDir}/bvals
bvecs=${dwiInputDir}/bvecs
data=${dwiInputDir}/data.nii.gz
gradDev=${dwiInputDir}/grad_dev.nii.gz
mask=${dwiInputDir}/nodif_brain_mask.nii.gz

smtDir=/data/grossman/hcp/bin/smt

export SMT_NUM_THREADS=$NSLOTS

if [[ -z "$SMT_NUM_THREADS" ]]; then 
  export SMT_NUM_THREADS=1
fi

export FSLDIR=/share/apps/fsl/5.0.9-eddy-patch

source ${FSLDIR}/etc/fslconf/fsl.sh

allB0=${outputDir}/allB0.nii.gz

# Get the unweighted images for noise computation
${FSLDIR}/bin/select_dwi_vols $data $bvals $allB0 0

echo "
--- `date`   Running Gaussian noise estimation ---"

if [[ ! -f ${outputDir}/gaussianNoise.nii.gz ]]; then
  ${smtDir}/gaussianfit --mask $mask $allB0 ${outputDir}/gaussianNoise.nii.gz
fi

echo "
--- `date`   Running Rician noise estimation ---"

if [[ ! -f ${outputDir}/ricianNoise.nii.gz ]]; then
  ${smtDir}/ricianfit --mask $mask $allB0 ${outputDir}/ricianNoise.nii.gz
fi

echo "
--- `date`   Running microscopic DT fit ---"

${smtDir}/fitmicrodt --bvals $bvals --bvecs $bvecs --graddev $gradDev --mask $mask $data ${outputDir}/mdt_{}.nii.gz

echo "
--- `date`   Running microscopic multi-compartment fit ---"

${smtDir}/fitmcmicro --bvals $bvals --bvecs $bvecs --graddev $gradDev --mask $mask $data ${outputDir}/mmc_{}.nii.gz

