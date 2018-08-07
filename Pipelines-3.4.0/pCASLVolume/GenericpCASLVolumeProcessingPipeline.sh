#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP) , gradunwarp (HCP version 1.0.2) 
#  environment: use SetUpHCPPipeline.sh  (or individually set FSLDIR, FREESURFER_HOME, HCPPIPEDIR, PATH - for gradient_unwarp.py)

########################################## PIPELINE OVERVIEW ########################################## 

# TODO

########################################## OUTPUT DIRECTORIES ########################################## 

# TODO

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

################################################ SUPPORT FUNCTIONS ##################################################

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage information To Be Written"
    exit 1
}

# --------------------------------------------------------------------------------
#   Establish tool name for logging
# --------------------------------------------------------------------------------
log_SetToolName "GenericpCASLVolumeProcessingPipeline.sh"

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# parse arguments
Path=`opts_GetOpt1 "--path" $@`  # "$1"
Subject=`opts_GetOpt1 "--subject" $@`  # "$2"
NameOffMRI=`opts_GetOpt1 "--fmriname" $@`  # "$6"
fMRITimeSeries=`opts_GetOpt1 "--fmritcs" $@`  # "$3"
# SpinEchoPhaseEncodeNegative=`opts_GetOpt1 "--SEPhaseNeg" $@`  # "$7"
# SpinEchoPhaseEncodePositive=`opts_GetOpt1 "--SEPhasePos" $@`  # "$5"
MagnitudeInputName=`opts_GetOpt1 "--fmapmag" $@`  # "$8" #Expects 4D volume with two 3D timepoints
# PhaseInputName=`opts_GetOpt1 "--fmapphase" $@`  # "$9"
# DwellTime=`opts_GetOpt1 "--echospacing" $@`  # "${11}"
# deltaTE=`opts_GetOpt1 "--echodiff" $@`  # "${12}"
UnwarpDir=`opts_GetOpt1 "--unwarpdir" $@`  # "${13}"
FinalfMRIResolution=`opts_GetOpt1 "--fmrires" $@`  # "${14}"
DistortionCorrection=`opts_GetOpt1 "--dcmethod" $@`  # "${17}" #FIELDMAP or TOPUP
GradientDistortionCoeffs=`opts_GetOpt1 "--gdcoeffs" $@`  # "${18}"
TopupConfig=`opts_GetOpt1 "--topupconfig" $@`  # "${20}" #NONE if Topup is not being used
RUN=`opts_GetOpt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)
fMRIM0="$MagnitudeInputName"
# Setup PATHS
PipelineScripts=${HCPPIPEDIR_pCASLVol}
GlobalScripts=${HCPPIPEDIR_Global}
echo " PipelineScripts $PipelineScripts "
echo " GlobalScripts $GlobalScripts "

#Naming Conventions
T1wImage="T1w_acpc_dc"
T1wRestoreImage="T1w_acpc_dc_restore"
T1wRestoreImageBrain="T1w_acpc_dc_restore_brain"
T1wFolder="T1w" #Location of T1w images
AtlasSpaceFolder="MNINonLinear"
ResultsFolder="Results"
BiasField="BiasField_acpc_dc"
BiasFieldMNI="BiasField"
T1wAtlasName="T1w_restore"
MovementRegressor="Movement_Regressors" #No extension, .txt appended
MotionMatrixFolder="MotionMatrices"
MotionMatrixPrefix="MAT_"
FieldMapOutputName="FieldMap"
MagnitudeOutputName="Magnitude"
MagnitudeBrainOutputName="Magnitude_brain"
# ScoutName="Scout"
M0Name="M0"
# OrigScoutName="${ScoutName}_orig"
OrigM0Name="${M0Name}_orig"
OrigTCSName="${NameOffMRI}_orig"
FreeSurferBrainMask="brainmask_fs"
fMRI2strOutputTransform="${NameOffMRI}2str"
# RegOutput="Scout2T1w"
RegOutput="CBF2T1w"
CBFAtlas="CBF_MNI${FinalfMRIResolution}mm"
AtlasTransform="acpc_dc2standard"
OutputfMRI2StandardTransform="${NameOffMRI}2standard"
Standard2OutputfMRITransform="standard2${NameOffMRI}"
QAImage="T1wMulpCASL"
JacobianOut="Jacobian"

########################################## DO WORK ########################################## 

T1wFolder="$Path"/"$Subject"/"$T1wFolder"
AtlasSpaceFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"
ResultsFolder="$AtlasSpaceFolder"/"$ResultsFolder"/"$NameOffMRI"

fMRIFolder="$Path"/"$Subject"/"$NameOffMRI"
if [ ! -e "$fMRIFolder" ] ; then
  log_Msg "mkdir ${fMRIFolder}"
  mkdir "$fMRIFolder"
fi
# Copy original files to fMRI directory
cp "$fMRITimeSeries" "$fMRIFolder"/"$OrigTCSName".nii.gz
cp "$fMRIM0" "$fMRIFolder"/"$OrigM0Name".nii.gz

# commented because M0 MUST. MUST. exist because of background selection used in pCASL sequence
#Create fake "M0" if it doesn't exist
# if [ $fMRIM0 = "NONE" ] ; then
#  ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$OrigM0Name" 0 1
# else
#  cp "$fMRIScout" "$fMRIFolder"/"$OrigM0Name".nii.gz
# fi

#Gradient Distortion Correction of pCASL
if [ ! -f "$fMRIFolder"/"$NameOffMRI"_gdc.nii.gz ] ; then
log_Msg "Gradient Distortion Correction of pCASL"
if [ ! ${GradientDistortionCoeffs} == NONE ] ; then 
    log_Msg "PERFORMING GRADIENT DISTORTION CORRECTION" 
    # run  grad dist corr
    log_Msg "mkdir -p ${fMRIFolder}/GradientDistortionUnwarp"
    mkdir -p "$fMRIFolder"/GradientDistortionUnwarp
    ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
        --workingdir="$fMRIFolder"/GradientDistortionUnwarp \
        --coeffs="$GradientDistortionCoeffs" \
        --in="$fMRIFolder"/"$OrigTCSName" \
        --out="$fMRIFolder"/"$NameOffMRI"_gdc \
        --owarp="$fMRIFolder"/"$NameOffMRI"_gdc_warp

    log_Msg "mkdir -p ${fMRIFolder}/${M0Name}_GradientDistortionUnwarp"
    mkdir -p "$fMRIFolder"/"$M0Name"_GradientDistortionUnwarp
    ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
         --workingdir="$fMRIFolder"/"$M0Name"_GradientDistortionUnwarp \
         --coeffs="$GradientDistortionCoeffs" \
         --in="$fMRIFolder"/"$OrigM0Name" \
         --out="$fMRIFolder"/"$M0Name"_gdc \
         --owarp="$fMRIFolder"/"$M0Name"_gdc_warp
else
    log_Msg "NOT PERFORMING GRADIENT DISTORTION CORRECTION"
    # cp and name files to fake distortion correction
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$NameOffMRI"_gdc
    ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$NameOffMRI"_gdc "$fMRIFolder"/"$NameOffMRI"_gdc_warp 0 3
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$NameOffMRI"_gdc_warp -mul 0 "$fMRIFolder"/"$NameOffMRI"_gdc_warp
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$OrigM0Name" "$fMRIFolder"/"$M0Name"_gdc
fi
else 
    log_Msg "${GlobalScripts}/GradientDistortionUnwarp.sh already run, skipping"
fi

# Coregister M0 volumes using flirt
# I chose to do this post-gdc, assuming that if there is any motion, the distortions could make motion look worse. If things are funny, this could just as easily be done prior to GDC of M0 
${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$M0Name"_gdc -Tmean "$fMRIFolder"/"$M0Name"_gdc_mean
${RUN} ${HCPPIPEDIR_Global}/mcflirt_acc.sh "$fMRIFolder"/"$M0Name"_gdc "$fMRIFolder"/"$M0Name"_gdc_mc "$fMRIFolder"/"$M0Name"_gdc_mean
${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$M0Name"_gdc_mc.nii.gz -Tmean "$fMRIFolder"/"$M0Name"_gdc_mc_mean


if [ ! -f "$fMRIFolder"/"$NameOffMRI"_mc.nii.gz ] ; then
    log_Msg "mkdir -p ${fMRIFolder}/MotionCorrection_FLIRTbased"
    mkdir -p "$fMRIFolder"/MotionCorrection_FLIRTbased
    ${RUN} "$PipelineScripts"/MotionCorrection_FLIRTbased.sh \
    "$fMRIFolder"/MotionCorrection_FLIRTbased \
    "$fMRIFolder"/"$NameOffMRI"_gdc \
    "$fMRIFolder"/"$M0Name"_gdc_mc_mean \
    "$fMRIFolder"/"$NameOffMRI"_mc \
    "$fMRIFolder"/"$MovementRegressor" \
    "$fMRIFolder"/"$MotionMatrixFolder" \
    "$MotionMatrixPrefix" 
else
    log_Msg "${PipelineScripts}/MotionCorrection_FLIRTbased.sh already run, skipping"
fi

# distortion correction normally goes here, but this pcasl is spiral not EPI so I'm skipping it becaue I don't know what else to do because nobody told me about a field map
# So, let's just stick this together
#Sprial to T1w Registration
log_Msg "CBF Quantificatin and SPIRAL to T1w Registration"
if [ -e ${fMRIFolder}/CBFQuantificationAndSPIRALToT1wReg_FLIRTBBRAndFreeSurferBBRbased ] ; then
  rm -r ${fMRIFolder}/CBFQuantificationAndSPIRALToT1wReg_FLIRTBBRAndFreeSurferBBRbased
fi
log_Msg "mkdir -p ${fMRIFolder}/CBFQuantificationAndSPIRALToT1wReg_FLIRTBBRAndFreeSurferBBRbased "
mkdir -p ${fMRIFolder}/CBFQuantificationAndSPIRALToT1wReg_FLIRTBBRAndFreeSurferBBRbased

${RUN} ${PipelineScripts}/CBFQuantificationAndSPIRALToT1wReg_FLIRTBBRAndFreeSurferBBRbased.sh \
    --workingdir=${fMRIFolder}/CBFQuantificationAndSPIRALToT1wReg_FLIRTBBRAndFreeSurferBBRbased \
    --m0in=${fMRIFolder}/${M0Name}_gdc_mc_mean \
    --pcasl=${fMRIFolder}/${NameOffMRI}_mc \
    --t1=${T1wFolder}/${T1wImage} \
    --t1restore=${T1wFolder}/${T1wRestoreImage} \
    --t1brain=${T1wFolder}/${T1wRestoreImageBrain} \
    --owarp=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
    --oregim=${fMRIFolder}/${RegOutput} \
    --freesurferfolder=${T1wFolder} \
    --freesurfersubjectid=${Subject} \
    --qaimage=${fMRIFolder}/${QAImage} \
    --ojacobian=${fMRIFolder}/${JacobianOut} 

# Clean this up later
cp ${fMRIFolder}/CBFQuantificationAndSPIRALToT1wReg_FLIRTBBRAndFreeSurferBBRbased/CBF.nii.gz ${fMRIFolder}/CBF.nii.gz

#One Step Resampling
log_Msg "One Step Resampling"
log_Msg "mkdir -p ${fMRIFolder}/OneStepResampling"
# this is a problem. To achieve one step resampling I can't use gdc for CBF quantification, and then re-apply, but it seems dumb to me to wait until all the data is that unnatural before calculating CBF
# SO. Input here is the gradient corrected CBF map, which is then normalized into the MNI space using the convolved gdcM0-to-T1 and T1-to-MNI warps
# note that this means the output warps will additionally need the gdc warps or inverses to function. Not pretty. Not clean. But ugh.
mkdir -p ${fMRIFolder}/OneStepResampling
${RUN} ${PipelineScripts}/OneStepResampling.sh \
   --workingdir=${fMRIFolder}/OneStepResampling \
   --infmri=${fMRIFolder}/CBF.nii.gz \
   --t1=${AtlasSpaceFolder}/${T1wAtlasName} \
   --fmriresout=${FinalfMRIResolution} \
   --fmrifolder=${fMRIFolder} \
   --fmri2structin=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
   --struct2std=${AtlasSpaceFolder}/xfms/${AtlasTransform} \
   --owarp=${AtlasSpaceFolder}/xfms/${OutputfMRI2StandardTransform} \
   --oiwarp=${AtlasSpaceFolder}/xfms/${Standard2OutputfMRITransform} \
   --ofmri=${fMRIFolder}/${CBFAtlas}.nii.gz \
   --m0in=${fMRIFolder}/${M0Name}_gdc_mc_mean \
   --om0=${fMRIFolder}/${M0Name}_MNI \
   --freesurferbrainmask=${AtlasSpaceFolder}/${FreeSurferBrainMask} 


# note here could use MotionMatrix stuff if we did each volume separately, but I chose to calcucalte CBF in native pCASL (after gdc) before motion correction. Idea to 1) gradient correct before 2) motion correction and 3) calculate CBF there for optimal t/c alignment before 4) spatial normalization to template space
#   --gdfield=${fMRIFolder}/${NameOffMRI}_gdc_warp 
#   --motionmatdir=${fMRIFolder}/${MotionMatrixFolder} \
#   --motionmatprefix=${MotionMatrixPrefix} \
#   --biasfield=${AtlasSpaceFolder}/${BiasFieldMNI} \
#   --scoutin=${fMRIFolder}/${OrigScoutName} \
#   --scoutgdcin=${fMRIFolder}/${ScoutName}_gdc \
#   --oscout=${fMRIFolder}/${NameOffMRI}_SBRef_nonlin \
#   --jacobianin=${fMRIFolder}/${JacobianOut} \
#   --ojacobian=${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution}
    
#Intensity Normalization and Bias Removal
# log_Msg "Intensity Normalization and Bias Removal"
# ${RUN} ${PipelineScripts}/IntensityNormalization.sh \
#    --infmri=${fMRIFolder}/${NameOffMRI}_nonlin \
#    --biasfield=${fMRIFolder}/${BiasFieldMNI}.${FinalfMRIResolution} \
#    --jacobian=${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution} \
#    --brainmask=${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution} \
#    --ofmri=${fMRIFolder}/${NameOffMRI}_nonlin_norm \
#    --inscout=${fMRIFolder}/${NameOffMRI}_SBRef_nonlin \
#    --oscout=${fMRIFolder}/${NameOffMRI}_SBRef_nonlin_norm \
#    --usejacobian=false

log_Msg "mkdir -p ${ResultsFolder}"
mkdir -p ${ResultsFolder}
# MJ QUERY: WHY THE -r OPTIONS BELOW?
# TBr Response: Since the copy operations are specifying individual files
# to be copied and not directories, the recursive copy options (-r) to the
# cp calls below definitely seem unnecessary. They should be removed in 
# a code clean up phase when tests are in place to verify that removing them
# has no unexpected bad side-effect.
${RUN} cp ${fMRIFolder}/${CBFAtlas}.nii.gz ${ResultsFolder}/${CBFAtlas}.nii.gz

# ${RUN} cp -r ${fMRIFolder}/${MovementRegressor}.txt ${ResultsFolder}/${MovementRegressor}.txt
# ${RUN} cp -r ${fMRIFolder}/${MovementRegressor}_dt.txt ${ResultsFolder}/${MovementRegressor}_dt.txt
# ${RUN} cp -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}_SBRef.nii.gz
# ${RUN} cp -r ${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_${JacobianOut}.nii.gz
# ${RUN} cp -r ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}
###Add stuff for RMS###
# ${RUN} cp -r ${fMRIFolder}/Movement_RelativeRMS.txt ${ResultsFolder}/Movement_RelativeRMS.txt
# ${RUN} cp -r ${fMRIFolder}/Movement_AbsoluteRMS.txt ${ResultsFolder}/Movement_AbsoluteRMS.txt
# ${RUN} cp -r ${fMRIFolder}/Movement_RelativeRMS_mean.txt ${ResultsFolder}/Movement_RelativeRMS_mean.txt
# ${RUN} cp -r ${fMRIFolder}/Movement_AbsoluteRMS_mean.txt ${ResultsFolder}/Movement_AbsoluteRMS_mean.txt
###Add stuff for RMS###

log_Msg "Completed"

