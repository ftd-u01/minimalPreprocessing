#!/bin/bash 

get_batch_options() {
    local arguments=($@)

    unset command_line_specified_study_folder
    unset command_line_specified_subj_list
    unset command_line_specified_run_local

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --Subjlist=*)
                command_line_specified_subj_list=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --runlocal)
                command_line_specified_run_local="TRUE"
                index=$(( index + 1 ))
                ;;
            *) # Need this block or you get into an infinite loop if there's a typo in the args
                echo "Unrecognized arg ${argument}"
                exit 1 
                ;;
        esac
    done
}



get_batch_options $@

StudyFolder="" #Location of Subject folders (named by subjectID)
Subjlist="" #Space delimited list of subject IDs
# Sourced from wrapper script
# EnvironmentScript="/data/grossman/hcp/scripts/Pipelines-3.4.0/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environment script

# Require a command line input or print usage and exit

USAGE="

  $0 --StudyFolder=/path/to/data --Subjlist=\"subject1 subject2\" --runlocal

  This script is for running the HCP preprocessing pipelines on SC3T Prisma data using the July 2016 CCF protocols.

  Required args:

  --StudyFolder : path to data directory. Subject data lives inside here in /path/to/data/subjectID/ directories

  --Subjlist : List of subjects, separated by spaces

  --runlocal : You should probably qsub a script that calls this script with --runlocal. Otherwise FSL's qsub gets called, which might not work
"

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
else
  echo "$USAGE"
  exit 1
fi

if [ -n "${command_line_specified_subj_list}" ]; then
    Subjlist="${command_line_specified_subj_list}"
else
  echo "$USAGE"
  exit 1
fi

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP), gradunwarp (HCP version 1.0.2) if doing gradient distortion correction
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
# . ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
    QUEUE="all.q"
#fi

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-q veryshort.q"


########################################## INPUTS ########################################## 

#Scripts called by this script do NOT assume anything about the form of the input names or paths.
#This batch script assumes the HCP raw data naming convention, e.g.

#	${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_T1w_MPR1.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR2/${Subject}_3T_T1w_MPR2.nii.gz

#	${StudyFolder}/${Subject}/unprocessed/3T/T2w_SPC1/${Subject}_3T_T2w_SPC1.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/T2w_SPC2/${Subject}_3T_T2w_SPC2.nii.gz

#	${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Magnitude.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Phase.nii.gz

#Change Scan Settings: Sample Spacings, and $UnwarpDir to match your images
#These are set to match the HCP Protocol by default

#You have the option of using either gradient echo field maps or spin echo field maps to 
#correct your structural images for readout distortion, or not to do this correction at all
#Change either the gradient echo field map or spin echo field map scan settings to match your data
#The default is to use gradient echo field maps using the HCP Protocol

#If using gradient distortion correction, use the coefficents from your scanner
#The HCP gradient distortion coefficents are only available through Siemens
#Gradient distortion in standard scanners like the Trio is much less than for the HCP Skyra.


######################################### DO WORK ##########################################


for Subject in $Subjlist ; do
  echo $Subject
  
  #Input Images
  #Detect Number of T1w Images
  numT1ws=`ls ${StudyFolder}/${Subject}/unprocessed/3T | grep -P "T1w_MPR[0-9]$" | wc -l`
  echo "Found ${numT1ws} T1w Images for subject ${Subject}"
  T1wInputImages=""
  i=1
  while [ $i -le $numT1ws ] ; do
    T1wInputImages=`echo "${T1wInputImages}${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR${i}/${Subject}_3T_T1w_MPR${i}.nii.gz@"`
    i=$(($i+1))
  done
  
  #Detect Number of T2w Images
  numT2ws=`ls ${StudyFolder}/${Subject}/unprocessed/3T | grep -P "T2w_SPC[0-9]$" | wc -l`
  echo "Found ${numT2ws} T2w Images for subject ${Subject}"
  T2wInputImages=""
  i=1
  while [ $i -le $numT2ws ] ; do
    T2wInputImages=`echo "${T2wInputImages}${StudyFolder}/${Subject}/unprocessed/3T/T2w_SPC${i}/${Subject}_3T_T2w_SPC${i}.nii.gz@"`
    i=$(($i+1))
  done

  # Note - Scripts may be confused between exact definition of dwell time, echo spacing, and sample spacing. For now we use 
  # DwellTime = Echo spacing though they are not actually the same thing. Mark Elliott has more details.
  # 
  # Echo spacing for Prisma data from Mark (ms)
  # 
  # fieldmap: 0.59
  # rest_fmri: 0.58
  # dwi: 0.66
  # task_fmri: 0.58
  #
  

  #Readout Distortion Correction:

  # Distortion params set according to 
  # https://www.mail-archive.com/hcp-users@humanconnectome.org/msg01112.html

  AvgrdcSTRING="TOPUP" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = use spin echo field map
  
  #Using Regular Gradient Echo Field Maps (same as for fMRIVolume pipeline)
  MagnitudeInputName="NONE"
  #"${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Magnitude.nii.gz" #Expects 4D magitude volume with two 3D timepoints or "NONE" if not used
  PhaseInputName="NONE"
  #${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Phase.nii.gz" #Expects 3D phase difference volume or "NONE" if not used
  TE="NONE" # We don't have gradient maps but it's 2.24 for Uminn Lifespan T1 at 3T at http://lifespan.humanconnectome.org/data/LSCMRR_3T_printout_2014.08.15.pdf

  #Using Spin Echo Field Maps (same as for fMRIVolume pipeline)

  SpinEchoPhaseEncodeNegative="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_SpinEchoFieldMap_AP.nii.gz" #For the spin echo field map volume with a negative phase encoding direction (LR in HCP data, AP in 7T HCP data), set to NONE if using regular FIELDMAP
  SpinEchoPhaseEncodePositive="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_SpinEchoFieldMap_PA.nii.gz" #For the spin echo field map volume with a positive phase encoding direction (RL in HCP data, PA in 7T HCP data), set to NONE if using regular FIELDMAP
#  DwellTime="0.000580002668012" #Echo Spacing or Dwelltime of spin echo EPI MRI image, set to NONE if not used. Dwelltime = 1/(BandwidthPerPixelPhaseEncode * # of phase encoding samples): DICOM field (0019,1028) = BandwidthPerPixelPhaseEncode, DICOM field (0051,100b) AcquisitionMatrixText first value (# of phase encoding samples).  On Siemens, iPAT/GRAPPA factors have already been accounted for.  
  
  # No dicom group 0019 in our Prisma data
  #
  # Alternative formula from Michael Harms https://www.mail-archive.com/hcp-users@humanconnectome.org/msg00890.html
  #
  # For now, use 1 / (BandwidthPerPixelPhaseEncode * AcquisitionMatrixText)
  # 
  # gdcmdump -C  001_000006_000001.dcm | grep -i AcquisitionMatrixText
  # 16 - 'AcquisitionMatrixText' VM 1, VR SH, SyngoDT 22, NoOfItems 6, Data '104*104'
  # gdcmdump -C  001_000006_000001.dcm | grep -i Bandwidth
  # 79 - 'BandwidthPerPixelPhaseEncode' VM 1, VR FD, SyngoDT 4, NoOfItems 6, Data '16.57800000' 
  #
  # So use DwellTime = 1/(16.57800000*104)
  DwellTime="0.00058" 

  # Should be Y for AP / PA phase encode
  SEUnwarpDir="y" #x or y (minus or not does not matter) "NONE" if not used 
  TopupConfig="${HCPPIPEDIR_Config}/b02b0.cnf" #Config for topup or "NONE" if not used

  #Templates
  T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz" #Hires T1w MNI template
  T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain.nii.gz" #Hires brain extracted MNI template
  T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz" #Lowres T1w MNI template
  T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm.nii.gz" #Hires T2w MNI Template
  T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm_brain.nii.gz" #Hires T2w brain extracted MNI Template
  T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz" #Lowres T2w MNI Template
  TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz" #Hires MNI brain mask template
  Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz" #Lowres MNI brain mask template

  #Structural Scan Settings (set all to NONE if not doing readout distortion correction)

  # In connectome DB, these are set to 7400 and 2100 for LS data. But in the scripts, they are in s.
  #
  # https://www.mail-archive.com/hcp-users@humanconnectome.org/msg03874.html
  #
  # For T1: 
  #
  # gdcmdump -C 001_000014_000001.dcm | grep -i DwellTime
  # 11 - 'RealDwellTime' VM 1, VR IS, SyngoDT 6, NoOfItems 6, Data '7100    '
  # 
  # This is in ns according to Harms, so would be 0.0000071 s. This is close to LS setting of 0.0000074
  #
  # For T2:
  # gdcmdump -C 001_000016_000001.dcm | grep -i DwellTime
  # 11 - 'RealDwellTime' VM 1, VR IS, SyngoDT 6, NoOfItems 6, Data '2100    '
  # 
  T1wSampleSpacing="0.0000071" #DICOM field (0019,1018) in s or "NONE" if not used
  T2wSampleSpacing="0.0000021" #DICOM field (0019,1018) in s or "NONE" if not used

  # https://www.mail-archive.com/hcp-users@humanconnectome.org/msg00807.html
  #
  # Slices are sagittal, and phase is A >> P, so readout is either z or z-. HCP setting is z.
  UnwarpDir="z" 

  #Other Config Settings
  BrainSize="150" #BrainSize in mm, 150 for humans
  FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf" #FNIRT 2mm T1w Config
  # GradientDistortionCoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad" #Location of Coeffs file or "NONE" to skip
  # GradientDistortionCoeffs="/data/HCP_data/Siemens_Gradient_Coefficients/Penn_SC3T/coeff_AS82.grad" # Set to NONE to skip gradient distortion correction
  GradientDistortionCoeffs="/data/jet/PUBLIC/gradient_coefficients/Siemens/coeff_AS82_Prisma.grad"

  if [ -n "${command_line_specified_run_local}" ] ; then
      echo "About to run ${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh"
      queuing_command=""
  else
      echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh"
      queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
  fi

  ${queuing_command} ${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh \
      --path="$StudyFolder" \
      --subject="$Subject" \
      --t1="$T1wInputImages" \
      --t2="$T2wInputImages" \
      --t1template="$T1wTemplate" \
      --t1templatebrain="$T1wTemplateBrain" \
      --t1template2mm="$T1wTemplate2mm" \
      --t2template="$T2wTemplate" \
      --t2templatebrain="$T2wTemplateBrain" \
      --t2template2mm="$T2wTemplate2mm" \
      --templatemask="$TemplateMask" \
      --template2mmmask="$Template2mmMask" \
      --brainsize="$BrainSize" \
      --fnirtconfig="$FNIRTConfig" \
      --fmapmag="$MagnitudeInputName" \
      --fmapphase="$PhaseInputName" \
      --echodiff="$TE" \
      --SEPhaseNeg="$SpinEchoPhaseEncodeNegative" \
      --SEPhasePos="$SpinEchoPhaseEncodePositive" \
      --echospacing="$DwellTime" \
      --seunwarpdir="$SEUnwarpDir" \
      --t1samplespacing="$T1wSampleSpacing" \
      --t2samplespacing="$T2wSampleSpacing" \
      --unwarpdir="$UnwarpDir" \
      --gdcoeffs="$GradientDistortionCoeffs" \
      --avgrdcmethod="$AvgrdcSTRING" \
      --topupconfig="$TopupConfig" \
      --printcom=$PRINTCOM
      
  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

  echo "set -- --path=${StudyFolder} \
      --subject=${Subject} \
      --t1=${T1wInputImages} \
      --t2=${T2wInputImages} \
      --t1template=${T1wTemplate} \
      --t1templatebrain=${T1wTemplateBrain} \
      --t1template2mm=${T1wTemplate2mm} \
      --t2template=${T2wTemplate} \
      --t2templatebrain=${T2wTemplateBrain} \
      --t2template2mm=${T2wTemplate2mm} \
      --templatemask=${TemplateMask} \
      --template2mmmask=${Template2mmMask} \
      --brainsize=${BrainSize} \
      --fnirtconfig=${FNIRTConfig} \
      --fmapmag=${MagnitudeInputName} \
      --fmapphase=${PhaseInputName} \
      --echodiff=${TE} \
      --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
      --SEPhasePos=${SpinEchoPhaseEncodePositive} \
      --echospacing=${DwellTime} \
      --seunwarpdir=${SEUnwarpDir} \     
      --t1samplespacing=${T1wSampleSpacing} \
      --t2samplespacing=${T2wSampleSpacing} \
      --unwarpdir=${UnwarpDir} \
      --gdcoeffs=${GradientDistortionCoeffs} \
      --avgrdcmethod=${AvgrdcSTRING} \
      --topupconfig=${TopupConfig} \
      --printcom=${PRINTCOM}"

#  echo ". ${EnvironmentScript}"

done
