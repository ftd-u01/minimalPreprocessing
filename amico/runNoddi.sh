#!/bin/bash 

function checkFileExists {

  file=$1

  if [[ -f "$file" ]]; then
    return 0
  else
    echo " Required input $file missing or incorrect; see usage "
    exit 1
  fi 
}

if [[ $# -eq 0 ]]; then
  echo " 

  `basename $0` -i <data> -b <bvals> -r <bvecs> -m <mask> -o <outputDir> 

  Required args:

  -i : input data (4D NIFTI)

  -b : bvals

  -r : bvecs - pass bvecs from eddy
 
  -m : brain mask

  -o : output dir, absolute path (script runs from there)

"

exit 1

fi

brainMask=""
bvals=""
bvecs=""
data=""
version=""
outputDir=""

binDir=`dirname $0`

while getopts "b:i:m:o:r:" OPT
  do
  case $OPT in
      b)  # bvals
   bvals=$OPTARG
   ;;
      i)  # input image
   data=$OPTARG
   ;;
      m) # mask
   brainMask=$OPTARG
   ;;
      o)  # output
   outputDir=$OPTARG
   ;;
      r) # bvecs
   bvecs=$OPTARG
   ;;
     \?) # getopts issues an error message
   exit 1
   ;;
  esac
done

checkFileExists "$brainMask"
checkFileExists "$bvals" 
checkFileExists "$bvecs"
checkFileExists "$data"

if [[ ! -d "$outputDir" ]]; then
  mkdir -p "$outputDir"
fi

# Also copies data that the M-file refers to
${binDir}/generateNoddiM.pl $data $brainMask $bvals $bvecs $outputDir

echo "/share/apps/matlab/R2017a/bin/matlab -nodisplay -r run\(\'noddiScript.m\'\)" > ${outputDir}/noddi_qscript.sh

RAM=8G

# Use -q all.q,basic.q to run on older nodes

qsub -S /bin/bash -wd ${outputDir} -j y -o noddi.stdout -l h_vmem=${RAM},s_vmem=${RAM} ${outputDir}/noddi_qscript.sh 

sleep 0.25
