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
	    *)
                echo "Unrecognized arg ${argument}"
                exit 1 
                ;;
		
        esac
    done
}

get_batch_options $@


StudyFolder="" #Location of Subject folders (named by subjectID)
Subjlist="" #Space delimited list of subject IDs
# EnvironmentScript="/data/grossman/hcp/scripts/Pipelines-3.4.0/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environment script

# Require a command line input or print usage and exit

USAGE="

  $0 --StudyFolder=/path/to/data --Subjlist=\"subject1 subject2\" --runlocal

  This script is for running HCP Lifespan data from Penn's Prisma

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
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP) , gradunwarp (HCP version 1.0.2)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
# . ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q long.q"
#fi

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-q veryshort.q"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################


for Subject in $Subjlist ; do
  echo $Subject

  Tasklist=()

  # List all names of fMRI series dirs, will search for these and process them if found.
  # Will search for _AP and _PA so don't add those separately
  fMRISeriesTypes="tfMRI_GAMBLING tfMRI_WM rfMRI_REST1 rfMRI_REST2"

  for seriesID in $fMRISeriesTypes; do
    if [[ -d "${StudyFolder}/${Subject}/unprocessed/3T/${seriesID}_PA" ]]; then
      Tasklist[${#Tasklist[@]}]="${seriesID}_PA"
    fi

    if [[ -d "${StudyFolder}/${Subject}/unprocessed/3T/${seriesID}_AP" ]]; then
      Tasklist[${#Tasklist[@]}]="${seriesID}_AP"
    fi
  done


  for (( i = 0; i < ${#Tasklist[@]}; i++ )); do
    fMRIName=${Tasklist[i]}
    echo "  fMRI Surface processing ${fMRIName} "
    LowResMesh="32" #Needs to match what is in PostFreeSurfer, 32 is on average 2mm spacing between the vertices on the midthickness
    FinalfMRIResolution="2" #Needs to match what is in fMRIVolume, i.e. 2mm for 3T HCP data and 1.6mm for 7T HCP data
    SmoothingFWHM="2" #Recommended to be roughly the grayordinates spacing, i.e 2mm on HCP data 
    GrayordinatesResolution="2" #Needs to match what is in PostFreeSurfer. 2mm gives the HCP standard grayordinates space with 91282 grayordinates.  Can be different from the FinalfMRIResolution (e.g. in the case of HCP 7T data at 1.6mm)
    # RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)
    RegName="FS"

    if [ -n "${command_line_specified_run_local}" ] ; then
        echo "About to run ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
        queuing_command=""
    else
        echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
        queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
    fi

    ${queuing_command} ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
      --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --lowresmesh=$LowResMesh \
      --fmrires=$FinalfMRIResolution \
      --smoothingFWHM=$SmoothingFWHM \
      --grayordinatesres=$GrayordinatesResolution \
      --regname=$RegName

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

      echo "set -- --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --lowresmesh=$LowResMesh \
      --fmrires=$FinalfMRIResolution \
      --smoothingFWHM=$SmoothingFWHM \
      --grayordinatesres=$GrayordinatesResolution \
      --regname=$RegName"

      # echo ". ${EnvironmentScript}"
            
   done
done

