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
# EnvironmentScript="/data/grossman/hcp/scripts/Pipelines-3.4.0/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environmen

# Require a command line input or print usage and exit

USAGE="

  $0 --StudyFolder=/path/to/data --Subjlist=\"subject1 subject2\" --runlocal

  This script has been modified for CFN cluster use. It should be general to different data sources

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
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP), gradunwarp (HCP version 1.0.2)
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

  #Input Variables
  SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
  GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/91282_Greyordinates"
  GrayordinatesResolutions="2" #Usually 2mm, if multiple delimit with @, must already exist in templates dir
  HighResMesh="164" #Usually 164k vertices
  LowResMeshes="32" #Usually 32k vertices, if multiple delimit with @, must already exist in templates dir
  SubcorticalGrayLabels="${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt"
  FreeSurferLabels="${HCPPIPEDIR_Config}/FreeSurferAllLut.txt"
  ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases/Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii"
  # RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)
  RegName="FS" 

  if [ -n "${command_line_specified_run_local}" ] ; then
      echo "About to run ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
      queuing_command=""
  else
      echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
      queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
  fi

  ${queuing_command} ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh \
      --path="$StudyFolder" \
      --subject="$Subject" \
      --surfatlasdir="$SurfaceAtlasDIR" \
      --grayordinatesdir="$GrayordinatesSpaceDIR" \
      --grayordinatesres="$GrayordinatesResolutions" \
      --hiresmesh="$HighResMesh" \
      --lowresmesh="$LowResMeshes" \
      --subcortgraylabels="$SubcorticalGrayLabels" \
      --freesurferlabels="$FreeSurferLabels" \
      --refmyelinmaps="$ReferenceMyelinMaps" \
      --regname="$RegName" \
      --printcom=$PRINTCOM

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
  
   echo "set -- --path="$StudyFolder" \
      --subject="$Subject" \
      --surfatlasdir="$SurfaceAtlasDIR" \
      --grayordinatesdir="$GrayordinatesSpaceDIR" \
      --grayordinatesres="$GrayordinatesResolutions" \
      --hiresmesh="$HighResMesh" \
      --lowresmesh="$LowResMeshes" \
      --subcortgraylabels="$SubcorticalGrayLabels" \
      --freesurferlabels="$FreeSurferLabels" \
      --refmyelinmaps="$ReferenceMyelinMaps" \
      --regname="$RegName" \
      --printcom=$PRINTCOM"
      
  # echo ". ${EnvironmentScript}"
done

