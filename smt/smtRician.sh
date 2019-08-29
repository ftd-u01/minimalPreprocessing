#!/bin/bash

if [[ $# -eq 0 ]]; then
    echo "  $0 <subject> "
    exit 1
fi

subject=$1

baseDir=/data/grossman/hcp

outputDir=${baseDir}/smt/${subject}

mkdir -p $outputDir

tmpDir=$TMPDIR

if [[ ! -d "$TMPDIR" ]]; then
    tmpDir="/tmp/smtRician${subject}"
    mkdir -p $tmpDir
fi

t1InputDir=${baseDir}/subjectsPreProc/${subject}/T1w
dwiInputDir=${t1InputDir}/Diffusion
# Use this to get WM segmentation in diffusion space
dtiDir=${baseDir}/DTI/${subject}

bvals=${dwiInputDir}/bvals
bvecs=${dwiInputDir}/bvecs
data=${dwiInputDir}/data.nii.gz
gradDev=${dwiInputDir}/grad_dev.nii.gz
mask=${dwiInputDir}/nodif_brain_mask.nii.gz

aseg=${dtiDir}/${subject}_aparc+aseg.nii.gz

# Need a recent c3d
c3dDir=/data/grossman/hcp/bin/c3d

smtDir=/data/grossman/hcp/bin/smt

export SMT_NUM_THREADS=$NSLOTS

if [[ -z "$SMT_NUM_THREADS" ]]; then 
    export SMT_NUM_THREADS=1
fi

export FSLDIR=/share/apps/fsl/5.0.9-eddy-patch

source ${FSLDIR}/etc/fslconf/fsl.sh

allB0=${tmpDir}/allB0.nii.gz

# Get the unweighted images for noise computation
${FSLDIR}/bin/select_dwi_vols $data $bvals $allB0 0

echo "
--- `date`   Running Rician noise estimation ---"

if [[ ! -f ${outputDir}/ricianNoise.nii.gz ]]; then
    ${smtDir}/ricianfit --mask $mask $allB0 ${outputDir}/ricianB0_{}.nii.gz
fi

# average Rician scale parameter over WM

# Get WM from the aseg
${c3dDir}/c3d $aseg -retain-labels 2 41 251 252 253 254 255 -thresh 1 Inf 1 0 ${outputDir}/ricianB0_scale.nii.gz -multiply -o ${tmpDir}/ricianStd.nii.gz

sigma=`${FSLDIR}/bin/fslstats ${tmpDir}/ricianStd.nii.gz -M`

echo " 
  Mean Rician sigma in WM : $sigma 
"

echo "
--- `date`   Running microscopic DT fit ---"

${smtDir}/fitmicrodt --bvals $bvals --bvecs $bvecs --graddev $gradDev --mask $mask --rician $sigma $data ${outputDir}/mdtRician_{}.nii.gz

echo "
--- `date`   Running microscopic multi-compartment fit ---"

${smtDir}/fitmcmicro --bvals $bvals --bvecs $bvecs --graddev $gradDev --mask $mask --rician $sigma $data ${outputDir}/mmcRician_{}.nii.gz


rm ${tmpDir}/*
rmdir $tmpDir