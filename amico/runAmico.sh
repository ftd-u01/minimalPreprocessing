#!/bin/bash 

if [[ $# -eq 0 ]]; then
  echo " 

  `basename $0` <subject>  
"

exit 1

fi

subject=$1

binDir=`dirname $0`

# Also copies data that the M-file refers to

echo "
  Importing DWI data for $subject
"

# Copies raw data, and generates amicoModelFit.m, which we run in a qsub job
${binDir}/generateAmicoM.pl $subject

if [[ $? -ne 0 ]]; then
  echo "
  AMICO data initialization failed
"
  exit 1
fi

amicoDataDir=/data/grossman/hcp/amico/HCP_Lifespan/${subject}

echo "/share/apps/matlab/R2017a/bin/matlab -nodisplay -r run\(\'amicoModelFit.m\'\)
gzip *.nii AMICO/NODDI/*.nii
" > ${amicoDataDir}/amico_qscript.sh

RAM=12G

# Use -q all.q,basic.q to run on older nodes

qsub -S /bin/bash -wd ${amicoDataDir} -j y -o amico.stdout -l h_vmem=${RAM},s_vmem=${RAM} ${amicoDataDir}/amico_qscript.sh 

sleep 0.25
