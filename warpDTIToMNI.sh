#!/bin/bash

if [[ $# -eq 0 ]]; then
  echo " 

  $0 <subject> 

  Uses applywarp to resample data into MNI space

"
  
  exit 1
fi

subject=$1

baseDir=/data/grossman/hcp/

outDir=${baseDir}/DTI/${subject}

if [[ ! -d $outDir ]]; then
  echo " No DTI data for $subject "
  exit 1
fi

if [[ -z "$TMPDIR" ]]; then
  TMPDIR=/tmp
fi

subjMNIDir=${baseDir}/subjectsPreProc/${subject}/MNINonLinear

export HCPPIPEDIR=${baseDir}/scripts/Pipelines-3.4.0

# Use pipeline version of FSL
source ${baseDir}/scripts/Pipelines-3.4.0/Examples/Scripts/SetUpHCPPipeline.sh

# Add c3d
export PATH="/share/apps/c3d/c3d-1.1.0-Nightly-2016-02-26/bin/c3d:$PATH"


echo "
--- `date` Warping DTI scalars ---"

refImage=${outDir}/${subject}_T1w_MNI.nii.gz

# Make reference image at DTI resolution
c3d ${subjMNIDir}/T1w_restore_brain.nii.gz -resample-mm 1.5x1.5x1.5mm -o ${refImage}

# for full resolution
# cp ${subjMNIDir}/T1w_restore_brain.nii.gz $refImage
# cp ${subjMNIDir}/wmparc.nii.gz ${outDir}/${subject}_wmparc_MNI.nii.gz

applywarp --ref=${refImage} --in=${subjMNIDir}/wmparc.nii.gz --out=${outDir}/${subject}_wmparc_MNI.nii.gz --interp=nn

applywarp --ref=${refImage} --in=${baseDir}/subjectsPreProc/${subject}/T1w/aparc.a2009s+aseg.nii.gz --out=${outDir}/${subject}_aparc.a2009s+aseg_MNI.nii.gz --warp=${subjMNIDir}/xfms/acpc_dc2standard.nii.gz --interp=nn 

c3d ${outDir}/${subject}_L2.nii.gz ${outDir}/${subject}_L3.nii.gz -add -scale 0.5 -o ${outDir}/${subject}_RD.nii.gz

for scalar in FA MD RD; do
  applywarp --ref=${refImage} --in=${outDir}/${subject}_${scalar}.nii.gz --warp=${subjMNIDir}/xfms/acpc_dc2standard.nii.gz --out=${outDir}/${subject}_${scalar}_MNI.nii.gz
done

