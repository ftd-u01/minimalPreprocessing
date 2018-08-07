# Stauffer 6/2015
# Script to check for enviro settings needed by this version of HCP

ERROR=0

# Python - need version >= 2.7
# Python 2.6.6 is required by CentOS 6 for yum (and other apps?), so 2.7
# is installed in parallel in /share/apps
PVC=`python -V 2>&1 | grep 2.7.9 | cat | wc -l`
if [[ $PVC == 0 ]]; then
  echo
  echo "== ERROR =="
  echo "$0: 'python -V' did not return version 2.7.9"
  echo "Check your .bash_profile settings to make sure version 2.7.9 from "
  echo "/share/apps/python is in your PATH before /usr/bin/python"
  ERROR=1;
fi

# fsl - need version 5.0.6
FSLC=`which fsl 2> /dev/null | grep 5.0.6 | cat | wc -l`
if [[ $FSLC == 0 ]]; then
  echo
  echo "=== ERROR ==="
  echo "$0: default fsl version must be 5.0.6";
  echo "Instead, got " 
  which fsl
  echo
  ERROR=1;
fi

# FreeSurfer - version 5.3.0-HCP
FSV=`which freesurfer 2> /dev/null | grep 5.3.0-HCP | cat | wc -l`
if [[ $FSV == 0 ]]; then
  echo
  echo "=== ERROR ==="
  echo " $0: default freesurfer version must be 5.3.0-HCP."
  echo "Instead, got "
  which freesurfer
  echo
  ERROR=1;
fi

# FSL_DIR must equal FSLDIR
# FSL_DIR is defined by freesurfer's SetUpFreeSurfer.sh script using FSLDIR, but
# ONLY if FSL_DIR is not already defined.
if [[ "$FSL_DIR" != "$FSLDIR" ]]; then
  echo
  echo "=== ERROR ==="
  echo " $0: FSL_DIR must equal FSLDIR"
  echo " FSL_DIR: $FSL_DIR"
  echo " FSLDIR:  $FSLDIR"
  echo
  ERROR=1;
fi

if [[ $ERROR  == 1 ]]; then
  echo Check the settings in your $HOME/.bash_profile. Then logout and back in again.
  exit 1;
fi 

exit 0;
