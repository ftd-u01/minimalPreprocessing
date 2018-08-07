#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script to combine warps and affine transforms together and do a single resampling, with specified output resolution"
  echo " "
  echo "Usage: `basename $0` --workingdir=<working dir>"
  echo "             --infmri=<input 3D CBF image>"
  echo "             --t1=<input T1w restored image>"
  echo "             --fmriresout=<output resolution for images, typically the fmri resolution>"
  echo "             --fmrifolder=<fMRI processing folder>"
  echo "             --atlasspacedir=<output directory for several resampled images>"
  echo "             --fmri2structin=<input fMRI to T1w warp>"
  echo "             --struct2std=<input T1w to MNI warp>"
  echo "             --owarp=<output fMRI to MNI warp>"
  echo "             --oiwarp=<output MNI to fMRI warp>"
  echo "             --ofmri=<output CBF in MNI 3D image>"
  echo "             --freesurferbrainmask=<input FreeSurfer brain mask, nifti format in T1w space>"
  echo "             --m0in=<input M0 image (Spiral, no gradient non-linearity distortion correction)>"
  echo "             --om0=<output transformed M0 image>"
}
#  echo "             --gdfield=<input warpfield for gradient non-linearity correction>"
#  echo "             --motionmatdir=<input motion correcton matrix directory>"
#  echo "             --motionmatprefix=<input motion correcton matrix filename prefix>"
# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

################################################### OUTPUT FILES #####################################################

# Outputs (in $WD): 
#         NB: all these images are in standard space 
#             but at the specified resolution (to match the fMRI - i.e. low-res)
#     ${T1wImageFile}.${FinalfMRIResolution}  
#     ${FreeSurferBrainMaskFile}.${FinalfMRIResolution}
#     ${BiasFieldFile}.${FinalfMRIResolution}  
#     Scout_gdc_MNI_warp     : a warpfield from original (distorted) scout to low-res MNI
#
# Outputs (not in either of the above):
#     ${OutputTransform}  : the warpfield from fMRI to standard (low-res)
#     ${OutputfMRI}       
#     ${JacobianOut}
#     ${ScoutOutput}
#          NB: last three images are all in low-res standard space

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
InputfMRI=`getopt1 "--infmri" $@`  # "$2"
T1wImage=`getopt1 "--t1" $@`  # "$3"
FinalfMRIResolution=`getopt1 "--fmriresout" $@`  # "$4"
fMRIFolder=`getopt1 "--fmrifolder" $@`
fMRIToStructuralInput=`getopt1 "--fmri2structin" $@`  # "$6"
StructuralToStandard=`getopt1 "--struct2std" $@`  # "$7"
OutputTransform=`getopt1 "--owarp" $@`  # "$8"
OutputInvTransform=`getopt1 "--oiwarp" $@`
# MotionMatrixFolder=`getopt1 "--motionmatdir" $@`  # "$9"
# MotionMatrixPrefix=`getopt1 "--motionmatprefix" $@`  # "${10}"
OutputfMRI=`getopt1 "--ofmri" $@`  # "${11}"
FreeSurferBrainMask=`getopt1 "--freesurferbrainmask" $@`  # "${12}"
# BiasField=`getopt1 "--biasfield" $@`  # "${13}"
# GradientDistortionField=`getopt1 "--gdfield" $@`  # "${14}"
# ScoutInput=`getopt1 "--scoutin" $@`  # "${15}"
# ScoutInputgdc=`getopt1 "--scoutgdcin" $@`  # "${15}"
# ScoutOutput=`getopt1 "--oscout" $@`  # "${16}"
M0Input=`getopt1 "--m0in" $@`  # "${15}"
M0Output=`getopt1 "--om0" $@`  # "${16}"
# JacobianIn=`getopt1 "--jacobianin" $@`  # "${17}"
# JacobianOut=`getopt1 "--ojacobian" $@`  # "${18}"
# BiasFieldFile=`basename "$BiasField"`
T1wImageFile=`basename $T1wImage`
FreeSurferBrainMaskFile=`basename "$FreeSurferBrainMask"`

echo " "
echo " START: OneStepResampling"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt


########################################## DO WORK ########################################## 

#Save TR for later
# TR_vol=`${FSLDIR}/bin/fslval ${InputfMRI} pixdim4 | cut -d " " -f 1`
# NumFrames=`${FSLDIR}/bin/fslval ${InputfMRI} dim4`

# Create fMRI resolution standard space files for T1w image, wmparc, and brain mask
#   NB: don't use FLIRT to do spline interpolation with -applyisoxfm for the 
#       2mm and 1mm cases because it doesn't know the peculiarities of the 
#       MNI template FOVs
if [ ${FinalfMRIResolution} = "2" ] ; then
    ResampRefIm=$FSLDIR/data/standard/MNI152_T1_2mm
elif [ ${FinalfMRIResolution} = "1" ] ; then
    ResampRefIm=$FSLDIR/data/standard/MNI152_T1_1mm
else
  ${FSLDIR}/bin/flirt -interp spline -in ${T1wImage} -ref ${T1wImage} -applyisoxfm $FinalfMRIResolution -out ${WD}/${T1wImageFile}.${FinalfMRIResolution}
  ResampRefIm=${WD}/${T1wImageFile}.${FinalfMRIResolution} 
fi
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImage} -r ${ResampRefIm} --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${WD}/${T1wImageFile}.${FinalfMRIResolution}

# Create brain masks in this space from the FreeSurfer output (changing resolution)
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${FreeSurferBrainMask}.nii.gz -r ${WD}/${T1wImageFile}.${FinalfMRIResolution} --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}.nii.gz

# Create versions of the biasfield (changing resolution)
# ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${BiasField} -r ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${WD}/${BiasFieldFile}.${FinalfMRIResolution}
# ${FSLDIR}/bin/fslmaths ${WD}/${BiasFieldFile}.${FinalfMRIResolution} -thr 0.1 ${WD}/${BiasFieldFile}.${FinalfMRIResolution}

# Downsample warpfield (fMRI to standard) to increase speed 
#   NB: warpfield resolution is 10mm, so 1mm to fMRIres downsample loses no precision
${FSLDIR}/bin/convertwarp --relout --rel --warp1=${fMRIToStructuralInput} --warp2=${StructuralToStandard} --ref=${WD}/${T1wImageFile}.${FinalfMRIResolution} --out=${OutputTransform}

###Add stuff for RMS###
${FSLDIR}/bin/invwarp -w ${OutputTransform} -o ${OutputInvTransform} -r ${M0Input}
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${FreeSurferBrainMask}.nii.gz -r ${M0Input} -w ${OutputInvTransform} -o ${M0Input}_mask.nii.gz


${FSLDIR}/bin/imcp ${WD}/${T1wImageFile}.${FinalfMRIResolution} ${fMRIFolder}/${T1wImageFile}.${FinalfMRIResolution}
${FSLDIR}/bin/imcp ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution} ${fMRIFolder}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}

# mkdir -p ${WD}/prevols
# mkdir -p ${WD}/postvols

# Apply combined transformations to fMRI (combines gradient non-linearity distortion, motion correction, and registration to T1w space, but keeping fMRI resolution)
# ${FSLDIR}/bin/fslsplit ${InputfMRI} ${WD}/prevols/vol -t
# FrameMergeSTRING=""
# FrameMergeSTRINGII=""
# k=0

# # Combine transformations: gradient non-linearity distortion + fMRI_dc to standard
# ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/${T1wImageFile}.${FinalfMRIResolution} --warp1=${GradientDistortionField} --warp2=${OutputTransform} --out=${WD}/M0_gdc_MNI_warp.nii.gz

# Warp CBF to standard
# # ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${M0Input} -w ${WD}/Scout_gdc_MNI_warp.nii.gz -r ${WD}/${T1wImageFile}.${FinalfMRIResolution} -o ${M0Output}
# ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${M0Input} -w ${WD}/M0_gdc_MNI_warp.nii.gz -r ${WD}/${T1wImageFile}.${FinalfMRIResolution} -o ${M0Output}
# ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${InputfMRI} -w ${WD}/M0_gdc_MNI_warp.nii.gz -r ${WD}/${T1wImageFile}.${FinalfMRIResolution} -o ${OutputfMRI}
${FSLDIR}/bin/applywarp --rel --interp=spline --in=${M0Input} -w ${OutputTransform} -r ${WD}/${T1wImageFile}.${FinalfMRIResolution} -o ${M0Output}
${FSLDIR}/bin/applywarp --rel --interp=spline --in=${InputfMRI} -w ${OutputTransform} -r ${WD}/${T1wImageFile}.${FinalfMRIResolution} -o ${OutputfMRI}


# Create spline interpolated version of Jacobian  (T1w space, fMRI resolution)
# ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${JacobianIn} -r ${WD}/${T1wImageFile}.${FinalfMRIResolution} -w ${StructuralToStandard} -o ${JacobianOut}


echo " "
echo "END: OneStepResampling"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check registrations to low-res standard space" >> $WD/qa.txt
echo "fslview ${WD}/${T1wImageFile}.${FinalfMRIResolution} ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution} ${WD}/${BiasFieldFile}.${FinalfMRIResolution} ${OutputfMRI}" >> $WD/qa.txt

##############################################################################################


