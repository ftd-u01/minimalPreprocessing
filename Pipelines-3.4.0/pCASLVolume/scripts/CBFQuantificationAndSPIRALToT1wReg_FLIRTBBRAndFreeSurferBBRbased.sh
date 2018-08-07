#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6) and FreeSurfer (version 5.3.0-HCP)
#  environment: FSLDIR, FREESURFER_HOME + others

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script to register SPIRAL to T1w, (without distortion correction)"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>]"
  echo "             --t1=<input T1-weighted image>"
  echo "             --t1restore=<input bias-corrected T1-weighted image>"
  echo "             --t1brain=<input bias-corrected, brain-extracted T1-weighted image>"
  echo "             --owarp=<output filename for warp of EPI to T1w>"
  echo "             --oregim=<output registered image (EPI to T1w)>"
  echo "             --pcasl=<motion corrected pCASL image to process "
  echo "             --m0in=<m0 image. If acquired multi-volume, should already be co-registered and averaged" 
  echo "             --freesurferfolder=<directory of FreeSurfer folder>"
  echo "             --freesurfersubjectid=<FreeSurfer Subject ID>"
  echo "             [--qaimage=<output name for QA image>]"
  echo "             --ojacobian=<output filename for Jacobian image (in T1w space)>"

}
#  echo "             --gdcoeffs=<gradient non-linearity distortion coefficients (Siemens format)>"
#  echo "             --biasfield=<input bias field estimate image, in fMRI space>"
#  echo "             --scoutin=<input scout image (pre-sat EPI)>"
#  echo "             --fmapmag=<input fieldmap magnitude image>"
#  echo "             --fmapphase=<input fieldmap phase image>"
#  echo "             --echodiff=<difference of echo times for fieldmap, in milliseconds>"
#  echo "             --SEPhaseNeg=<input spin echo negative phase encoding image>"
#  echo "             --SEPhasePos=<input spin echo positive phase encoding image>"
#  echo "             --echospacing=<effective echo spacing of fMRI image, in seconds>"
#  echo "             --unwarpdir=<unwarping direction: x/y/z/-x/-y/-z>"
#  echo "             --method=<method used for distortion correction: FIELDMAP or TOPUP>"
#  echo "             [--topupconfig=<topup config file>]"

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
#  
#    FIELDMAP section only: 
#      Magnitude  Magnitude_brain  FieldMap
#
#    FIELDMAP and TOPUP sections: 
#      Jacobian2T1w
#      ${ScoutInputFile}_undistorted  
#      ${ScoutInputFile}_undistorted2T1w_init   
#      ${ScoutInputFile}_undistorted_warp
#
#    FreeSurfer section: 
#      fMRI2str.mat  fMRI2str
#      ${ScoutInputFile}_undistorted2T1w  
#
# Outputs (not in $WD):
#
#       ${RegOutput}  ${OutputTransform}  ${JacobianOut}  ${QAImage}



################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 7 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
M0Image=`getopt1 "--m0in" $@` # 
pCASLImage=`getopt1 "--pcasl" $@` # 
T1wImage=`getopt1 "--t1" $@`  # "$3"
T1wRestoreImage=`getopt1 "--t1restore" $@`  # "$4"
T1wBrainImage=`getopt1 "--t1brain" $@`  # "$5"
OutputTransform=`getopt1 "--owarp" $@`  # "${6}"
RegOutput=`getopt1 "--oregim" $@`  # "${7}"
FreeSurferSubjectFolder=`getopt1 "--freesurferfolder" $@`  # "${9}"
FreeSurferSubjectID=`getopt1 "--freesurfersubjectid" $@`  # "${10}"
QAImage=`getopt1 "--qaimage" $@`  # "${11}"
JacobianOut=`getopt1 "--ojacobian" $@`  # "${12}"

M0InputName=`basename $M0Image`
T1wBrainImageFile=`basename $T1wBrainImage`
T1wDir=`dirname $T1wBrainImage`
pCASLName=`basename $pCASLImage`

# default parameters
RegOutput=`$FSLDIR/bin/remove_ext $RegOutput`
WD=`defaultopt $WD ${RegOutput}.wdir`
GlobalScripts=${HCPPIPEDIR_Global}
# TopupConfig=`defaultopt $TopupConfig ${HCPPIPEDIR_Config}/b02b0.cnf`
UseJacobian=false

echo " "
echo " START: CBFQuantificationAndSPIRALToT1wReg_FLIRTBBRAndFreeSurferBBRbased"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt


########################################## DO WORK ########################################## 
# We have moco pCASL. Split it up to get tag and control volumes
${FSLDIR}/bin/fslsplit ${pCASLImage} ${WD}/pCASL_tmp3d -t 

# Get mean tag signal (fslsplit starts at 0)
tagImgs=`ls ${WD}/pCASL_tmp3d*[02468].nii.gz`
${FSLDIR}/bin/fslmerge -t ${WD}/pCASL_tags4d.nii.gz ${tagImgs}
${FSLDIR}/bin/fslmaths ${WD}/pCASL_tags4d.nii.gz -Tmean ${WD}/pCASL_tagMean.nii.gz

# Get mean control signal
controlImgs=`ls ${WD}/pCASL_tmp3d*[13579].nii.gz`
${FSLDIR}/bin/fslmerge -t ${WD}/pCASL_controls4d.nii.gz ${controlImgs}
${FSLDIR}/bin/fslmaths ${WD}/pCASL_controls4d.nii.gz -Tmean ${WD}/pCASL_controlMean.nii.gz

# Control value should be greater than tag value. Will also correct if T/C order is different with warning
tagVal=`${FSLDIR}/bin/fslstats ${WD}/pCASL_tagMean.nii.gz -m`
controlVal=`${FSLDIR}/bin/fslstats ${WD}/pCASL_controlMean.nii.gz -m`
if [ $(echo $controlVal '>' $tagVal | bc -l) == 1 ] ; then
  ${FSLDIR}/bin/fslmaths ${WD}/pCASL_controlMean.nii.gz -sub ${WD}/pCASL_tagMean.nii.gz ${WD}/perfusion.nii.gz 
else
  echo " Looks like confusion with tag/control order-- double check for your data "
  ${FSLDIR}/bin/fslmaths ${WD}/pCASL_tagMean.nii.gz -sub ${WD}/pCASL_controlMean.nii.gz ${WD}/perfusion.nii.gz
fi

# get CBF constant
# equation and values from Alsop et al 2015 Mag Resn Med
# This is hard coded for our 3d spiral pCASL sequence because bash sucks at numbers and I don't want 20 fslmaths commands
# list of values : 
	# lambda (blood brain partician coef) = .9 
	# omega (post labeling delay) = 1.8s 
	# bloodt1 = 1.65s (3T)
	# gmT1 = 1.445s (3T)
	# alpha (labeling efficiency) = .85 (pCASL)
	# TR = 4.2s (this sequence)
	# 3d aquisition so no slice time correction
	# tau (labeling duration) =1.8s
# perfConst <- 60 * 100 * lambda * exp( omega / bloodt1) / ( 2 * alpha * bloodt1 *(1 - exp(-tau / bloodt1)))
# correct constant for "short" TR <- use here for 4.2s 
# if (trASL < 5) {
#  perfConst <- perfConst / (1/(1-exp(-trASL/T1g))) } 
# also, uses background suppression, so divide by 10
# perfConst <- perfConst / 10
# all of that should equal 913. So there.
perfConst=913

# divide pcasl by M0 (separate M0 (NOT ESTIMATED) necessary for our background suppressed acquisition) ; multiply by perfusion constant to get CBF map
# note perfusion.nii.gz is based upon the gdc and motion corrected pcasl volumes and the M0 here should be the gdc + mean motion corrected volume. 
${FSLDIR}/bin/fslmaths ${WD}/perfusion.nii.gz -div ${M0Image}.nii.gz -mul ${perfConst} ${WD}/CBF.nii.gz

## clean up intermediate CBF files
rm ${tagImgs} ${controlImgs} ${WD}/pCASL_tags4d.nii.gz ${WD}/pCASL_controls4d.nii.gz ${WD}/pCASL_tagMean.nii.gz ${WD}/pCASL_controlMean.nii.gz ${WD}/perfusion.nii.gz

cp ${T1wBrainImage}.nii.gz ${WD}/${T1wBrainImageFile}.nii.gz


# make brain mask for pCASL scan 
	# steps done before BCFQuant script starts
	# 1. moco M0
	# 2. make avg moco M0
	# 3. moco pcasl to M0
	# stuff to do below
	# 4. get perfusion image from moco-ed pcasl
	# 5. quantify CBF
	# 6. register M0 to T1w, MNI, whatever else (probably using flirt then bbregister)
	# 7. apply transforms from 6 to CBF image


# #Run Normally
# flirt coregister
# WITHOUT bbregister
# ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${M0Image}.nii.gz -ref ${T1wImage} -omat ${WD}/M02T1w.mat -out ${WD}/M02T1w.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30

# WITH bbregister
# FLIRT-- coregister M0 image to T1. Outputs .mat for M0 -> T1
${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${M0Image}.nii.gz -ref ${T1wImage} -omat ${WD}/M02T1w_flirt.mat -out ${WD}/M02T1w_flirt.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
# Get inverse of M0 -> T1
${FSLDIR}/bin/convert_xfm -omat ${WD}/T1w2M0_flirt.mat -inverse ${WD}/M02T1w_flirt.mat
# cat ${WD}/T1w2M0_flirt.mat
# Get T1 brain mask into M0 space using inverse
awcmd="${FSLDIR}/bin/applywarp --interp=nn -i ${WD}/${T1wBrainImageFile} -r ${M0Image}.nii.gz --premat=${WD}/T1w2M0_flirt.mat -o ${WD}/M0_brain_mask.nii.gz"
# echo $awcmd   
$awcmd
# Get M0 brain mask
fslmaths ${WD}/M0_brain_mask.nii.gz -bin ${WD}/M0_brain_mask.nii.gz
# fslmaths ${M0Image}.nii.gz -mas ${WD}/M0_brain_mask.nii.gz ${WD}/M0_brain.nii.gz

# Clean up outside-of-brain noise
${FSLDIR}/bin/fslmaths ${WD}/CBF.nii.gz -mas ${WD}/M0_brain_mask.nii.gz ${WD}/CBF_brain.nii.gz
# ${FSLDIR}/bin/fslmaths ${WD}/CBF.nii.gz -mul ${WD}/${T1wBrainImageFile}_brainmask_2M0.nii.gz ${WD}/CBF.nii.gz

# Clean up inside-of-brain noise
# Low noise
${FSLDIR}/bin/fslmaths ${WD}/CBF_brain.nii.gz -thr 0 ${WD}/CBF_brain.nii.gz
# High noise to 0: high noise >= meanOfNon0 + 2*SDofNon0
meanVal=`${FSLDIR}/bin/fslstats ${WD}/CBF_brain.nii.gz -M `
sdVal=`${FSLDIR}/bin/fslstats ${WD}/CBF_brain.nii.gz -S `
meantwoSD=$(echo ${meanVal} + ${sdVal} + ${sdVal} | bc)
# if data clean, just using this could hack off real data, so make sure it never cuts off anything below 200, which is pretty much tail of noise in checks
ceilFloor=200.01
if (( $(bc <<< "$meantwoSD < $ceilFloor") )) ; then  
	meantwoSD=$ceilFloor
fi
${FSLDIR}/bin/fslmaths ${WD}/CBF_brain.nii.gz -uthr ${meantwoSD} ${WD}/CBF_brain.nii.gz

# Use ASL for epi_reg-- better GM/WM contrast than M0

# Register CBF brain to T1
${FSLDIR}/bin/epi_reg --epi=${WD}/CBF_brain.nii.gz --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/CBF_brain_normT1w_FAST


### FREESURFER BBR - found to be an improvement, probably due to better GM/WM boundary

# convert init fsl matrix to freesurfer dat file
# ${FREESURFER_HOME}/bin/tkregister2 --mov ${M0Image}.nii.gz --targ ${T1wImage}.nii.gz --reg ${WD}/M02T1w_init.dat --fsl ${WD}/M02T1w_init.mat --noedit
# sed -i "1s/.*/$FreeSurferSubjectID/" ${WD}/M02T1w_init.dat 

# bbregister using flirt: 2nd step
SUBJECTS_DIR=${FreeSurferSubjectFolder}
export SUBJECTS_DIR
echo $SUBJECTS_DIR
# convert fsl .mat to freesurfer .dat 
tkacmd="${FREESURFER_HOME}/bin/tkregister2 --noedit --mov ${WD}/CBF_brain.nii.gz --targ ${T1wImage}.nii.gz --fsl ${WD}/CBF_brain_normT1w_FAST.mat --reg ${WD}/CBF_brain_normT1w_FAST.dat"
echo $tkcmd
$tkcmd
# put subject id in there
sed -i "s/subject-unknown/${FreeSurferSubjectID}/" ${WD}/CBF_brain_normT1w_FAST.dat

# bbregister getting everything without interpolations
bbrcmd="${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/CBF_brain.nii.gz --surf white.deformed --init-reg ${WD}/CBF_brain_normT1w_FAST.dat --bold --reg ${WD}/CBF_brain_normT1w_FAST_bbr.dat --o ${WD}/CBF_brain_normT1w_FAST_bbr.nii.gz"
echo $bbrcmd
$bbrcmd

# convert it all 
tkbcmd="${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${WD}/CBF_brain_normT1w_FAST_bbr.dat --mov ${WD}/CBF_brain.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/CBF2T1w.mat"
echo $tkbcmd
$tkbcmd

# make it a nifti 
${FSLDIR}/bin/convertwarp --relout --rel --ref=${T1wImage} -m ${WD}/CBF2T1w.mat --out=${WD}/CBF2str.nii.gz

 #Run Normally
# Use bbregister to fine-tune registration. 
# ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/CBF_brain_normT1w_FAST.nii.gz --surf white.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat --bold --reg ${WD}/CBFtoT1w_bbr.dat --o ${WD}/CBF_brain_normT1w.nii.gz
# Create FSL-style matrix and then combine with existing warp fields
# ${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${WD}/CBFtoT1w_bbr.dat --mov ${WD}/CBF_brain_normT1w.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/CBF2T1w_bbr.mat

# ${FSLDIR}/bin/convertwarp --relout --rel --premat=${WD}/M02T1w_flirt.mat --ref=${T1wImage} --postmat=${WD}/CBF2T1w_bbr.mat --out=${WD}/CBF2str.nii.gz

# Create warped image with spline interpolation, bias correction and (optional) Jacobian modulation
# ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/CBF_brain.nii.gz -r ${T1wImage}.nii.gz -w ${WD}/CBF2str.nii.gz -o ${WD}/CBF_flirt_and_BBR_normT1w


cp ${WD}/CBF_brain_2T1w_FAST_bbr.nii.gz ${RegOutput}.nii.gz
cp ${WD}/CBF2str.nii.gz ${OutputTransform}.nii.gz


##### cut from fMRI
##  ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz --surf white.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat --bold --reg ${WD}/EPItoT1w.dat --o ${WD}/${ScoutInputFile}_undistorted2T1w.nii.gz
  # Create FSL-style matrix and then combine with existing warp fields
##   ${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${WD}/EPItoT1w.dat --mov ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/fMRI2str.mat
#fi
##  ${FSLDIR}/bin/convertwarp --relout --rel --warp1=${WD}/${ScoutInputFile}_undistorted_warp.nii.gz --ref=${T1wImage} --postmat=${WD}/fMRI2str.mat --out=${WD}/fMRI2str.nii.gz
# Create warped image with spline interpolation, bias correction and (optional) Jacobian modulation
## ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage}.nii.gz -w ${WD}/fMRI2str.nii.gz -o ${WD}/${ScoutInputFile}_undistorted2T1w
## cp ${WD}/${ScoutInputFile}_undistorted2T1w.nii.gz ${RegOutput}.nii.gz
## cp ${WD}/fMRI2str.nii.gz ${OutputTransform}.nii.gz
#### end cut from fMRI


#${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/M02T1w_init.nii.gz --surf white.deformed --epi-mask --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat --bold --reg ${WD}/M02T1w.dat --o ${WD}/M02T1w.nii.gz

# This flips the brain weird.
# bbregister seems to suck at aligning this somehow. 
# ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/M02T1w_init.nii.gz --surf white.deformed --init-reg ${WD}/M02T1w_init.dat --bold --reg ${WD}/M02T1w.dat --o ${WD}/M02T1w.nii.gz
# This does not align things properly
# ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/M02T1w_init.nii.gz --surf white.deformed --init-fsl --bold --reg ${WD}/M02T1w.dat --o ${WD}/M02T1w.nii.gz
# flips again
# ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/M02T1w_init.nii.gz --surf white.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat --bold --reg ${WD}/M02T1w.dat --o ${WD}/M02T1w.nii.gz
# M0 to t1 not well-aligned (flirt alone is better)
# ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${M0Image}.nii.gz --surf white.deformed --init-fsl --bold --reg ${WD}/M02T1w.dat --o ${WD}/M02T1w.nii.gz
# flipped. wrong wrong wrong.
# ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${M0Image}.nii.gz --surf white.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat --bold --reg ${WD}/M02T1w.dat --o ${WD}/M02T1w.nii.gz
# flips again.
# ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${M0Image}.nii.gz --surf white.deformed --init-reg ${WD}/M02T1w_init.dat --bold --reg ${WD}/M02T1w.dat --o ${WD}/M02T1w.nii.gz

# Create FSL-style matrix and then combine with (non-existent) existing warp fields (dat to mat conv)
# WITHOUT bbregister
# ${FREESURFER_HOME}/bin/tkregister2 --reg ${WD}/M02T1w.dat --mov ${M0Image}.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/M02T1w.mat --noedit 
# WITH bbregister
# SUBJECTS_DIR=${FreeSurferSubjectFolder}
# export SUBJECTS_DIR




# This may or may not be needed 
##${FREESURFER_HOME}/bin/tkregister2 --reg ${WD}/M02T1w.dat --mov ${WD}/M02T1w_init.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/M02T1w.mat --noedit 


# Create inverse mat
# ${FSLDIR}/bin/convert_xfm -omat ${WD}/T1w2M0.mat -inverse ${WD}/M02T1w.mat

# Get nifti format warp
# ${FSLDIR}/bin/convertwarp --relout --rel -r ${T1wImage} --premat=${WD}/M02T1w.mat -o ${WD}/${M0InputName}_toT1w_warp
# ${FSLDIR}/bin/convertwarp --relout --rel -r ${M0Image} --premat=${WD}/T1w2M0.mat -o ${WD}/${T1wBrainImageFile}_toM0_warp

# Warp t1 & brain mask to pcasl space (t1 for fun, brainmask for masking)
# ${FSLDIR}/bin/applywarp --interp=nn -i ${WD}/${T1wBrainImageFile}.nii.gz -r ${M0Image} --premat=${WD}/T1w2M0.mat -o ${WD}/${T1wBrainImageFile}_2M0.nii.gz    
# ${FSLDIR}/bin/applywarp --interp=nn -i ${T1wDir}/brainmask_fs.nii.gz -r ${M0Image} --premat=${WD}/T1w2M0.mat -o ${WD}/${T1wBrainImageFile}_brainmask_2M0.nii.gz


# Warp CBF to t1 
# ${FSLDIR}/bin/applywarp --interp=trilinear -i ${WD}/CBF.nii.gz -r ${WD}/${T1wBrainImageFile}.nii.gz --premat=${WD}/M02T1w.mat -o ${WD}/CBF2T1w.nii.gz   

# Copy stuff to T1w directory
# cp ${WD}/${M0InputName}_toT1w_warp.nii.gz ${OutputTransform}.nii.gz
# cp ${WD}/CBF2T1w.nii.gz ${RegOutput}.nii.gz
# cp ${WD}/M02T1w.nii.gz ${}.nii.gz

echo " "
echo " END: CBFQUantificationAndSPIRALToT1wReg_FLIRTBBRAndFreeSurferBBRBased"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

# if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
# echo "cd `pwd`" >> $WD/qa.txt
# echo "# Check registration of SPIRAL to T1w (with all corrections applied)" >> $WD/qa.txt
# echo "fslview ${T1wRestoreImage} ${RegOutput} ${QAImage}" >> $WD/qa.txt
# echo "# Check undistortion of the scout image" >> $WD/qa.txt
# echo "fslview `dirname ${ScoutInputName}`/GradientDistortionUnwarp/Scout ${WD}/${ScoutInputFile}_undistorted" >> $WD/qa.txt

echo " check stuff "
##############################################################################################

