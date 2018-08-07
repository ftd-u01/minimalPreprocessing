#!/bin/bash 

# echo "This script must be SOURCED to correctly setup the environment prior to running any of the other HCP scripts contained here"

# Set up FSL (if not already done so in the running environment)
#FSLDIR=/usr/share/fsl/5.0
#. ${FSLDIR}/etc/fslconf/fsl.sh

# Set up FreeSurfer (if not already done so in the running environment)
#FREESURFER_HOME=/usr/local/bin/freesurfer
#. ${FREESURFER_HOME}/SetUpFreeSurfer.sh > /dev/null 2>&1

# Set up specific environment variables for the HCP Pipeline

### CfN modified
# Define this externally so that this code is more portable
if [[ -z "$HCPPIPEDIR" ]]; then
  echo "   
  ERROR: HCPPIPEDIR undefined, must be defined prior to running HCP pipeline scripts
"
  return
fi
#export HCPPIPEDIR=${HOME}/data/grossman/hcp/scripts/Pipelines-3.4.0
# export HCPPIPEDIR=/data/grossman/hcp/scripts/Pipelines-3.4.0
#export CARET7DIR=${HOME}/share/apps/workbench/workbench-1.0/bin_rh_linux64
export CARET7DIR=/share/apps/workbench/workbench-1.0/bin_rh_linux64

export FSLDIR=$CFNAPPS/fsl/5.0.6
if [ -d "$FSLDIR" ]; then
  source ${FSLDIR}/etc/fslconf/fsl.sh
else
  echo " ERROR: Can't find FSL at $FSLDIR "
fi
PATH=${FSLDIR}/bin:${PATH}

# Freesurfer uses its own FSL_DIR variable?!
export FSL_DIR=$FSLDIR

## Freesurfer
#export FREESURFER_HOME=$CFNAPPS/freesurfer/5.3.0
#Use 5.3.0-HCP for use with HCP Pipelines 3.4.0
export FREESURFER_HOME=$CFNAPPS/freesurfer/5.3.0-HCP

if [ -f "$FREESURFER_HOME/SetUpFreeSurfer.sh" ]; then
  source $FREESURFER_HOME/SetUpFreeSurfer.sh
else
  echo " ERROR: Can't find FreeSurfer at $FREESURFER_HOME "
fi

# python
# version required for HCP pipelines. Installed in parallel with system's version 2.6.6
export PyPATH=$CFNAPPS/python/Python-2.7.9/bin/
# Put this BEFORE /usr/bin so we don't get the system python.
PATH=$PyPATH:$PATH


# Run custom script to check env settings for fsl, freesurfer and python
${HCPPIPEDIR}/VerifyHCPpipelinesEnvironment.sh

export OMP_NUM_THREADS=1

# This defined on CFN cluster for qsub / qlogin jobs
if [[ ! -z "$NSLOTS" ]]; then
    export OMP_NUM_THREADS=$NSLOTS
fi

### end CfN modified

export HCPPIPEDIR_Templates=${HCPPIPEDIR}/global/templates
export HCPPIPEDIR_Bin=${HCPPIPEDIR}/global/binaries
export HCPPIPEDIR_Config=${HCPPIPEDIR}/global/config

export HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts
export HCPPIPEDIR_FS=${HCPPIPEDIR}/FreeSurfer/scripts
export HCPPIPEDIR_PostFS=${HCPPIPEDIR}/PostFreeSurfer/scripts
export HCPPIPEDIR_fMRISurf=${HCPPIPEDIR}/fMRISurface/scripts
export HCPPIPEDIR_fMRIVol=${HCPPIPEDIR}/fMRIVolume/scripts
export HCPPIPEDIR_pCASLSurf=${HCPPIPEDIR}/pCASLSurface/scripts
export HCPPIPEDIR_pCASLVol=${HCPPIPEDIR}/pCASLVolume/scripts
export HCPPIPEDIR_tfMRI=${HCPPIPEDIR}/tfMRI/scripts
export HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts
export HCPPIPEDIR_dMRITract=${HCPPIPEDIR}/DiffusionTractography/scripts
export HCPPIPEDIR_Global=${HCPPIPEDIR}/global/scripts
export HCPPIPEDIR_tfMRIAnalysis=${HCPPIPEDIR}/TaskfMRIAnalysis/scripts
export MSMBin=${HCPPIPEDIR}/MSMBinaries

## WASHU config - as understood by MJ - (different structure from the GIT repository)
## Also look at: /nrgpackages/scripts/tools_setup.sh

# Set up FSL (if not already done so in the running environment)
#FSLDIR=/nrgpackages/scripts
#. ${FSLDIR}/fsl5_setup.sh

# Set up FreeSurfer (if not already done so in the running environment)
#FREESURFER_HOME=/nrgpackages/tools/freesurfer5
#. ${FREESURFER_HOME}/SetUpFreeSurfer.sh

#NRG_SCRIPTS=/nrgpackages/scripts#. ${NRG_SCRIPTS}/epd-python_setup.sh

#export HCPPIPEDIR=/home/NRG/jwilso01/dev/Pipelines
#export HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts
#export HCPPIPEDIR_FS=/data/intradb/pipeline/catalog/StructuralHCP/resources/scripts
#export HCPPIPEDIR_PostFS=/data/intradb/pipeline/catalog/StructuralHCP/resources/scripts

#export HCPPIPEDIR_FIX=/data/intradb/pipeline/catalog/FIX_HCP/resources/scripts
#export HCPPIPEDIR_Diffusion=/data/intradb/pipeline/catalog/DiffusionHCP/resources/scripts
#export HCPPIPEDIR_Functional=/data/intradb/pipeline/catalog/FunctionalHCP/resources/scripts

#export HCPPIPETOOLS=/nrgpackages/tools/HCP
#export HCPPIPEDIR_Templates=/nrgpackages/atlas/HCP
#export HCPPIPEDIR_Bin=${HCPPIPETOOLS}/bin
#export HCPPIPEDIR_Config=${HCPPIPETOOLS}/conf
#export HCPPIPEDIR_Global=${HCPPIPETOOLS}/scripts_v2

#export CARET7DIR=${HCPPIPEDIR_Bin}/caret7/bin_linux64
## may or may not want the above variables to be setup as above
##    (if so then the HCPPIPEDIR line needs to go before them)
## end of WASHU config


# The following is probably unnecessary on most systems
#PATH=${PATH}:/vols/Data/HCP/pybin/bin/
#PYTHONPATH=/vols/Data/HCP/pybin/lib64/python2.6/site-packages/


#echo "Unsetting SGE_ROOT for testing mode only"
#unset SGE_ROOT

