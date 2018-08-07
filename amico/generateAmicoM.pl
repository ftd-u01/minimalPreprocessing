#!/usr/bin/perl -w


use strict;

use File::Spec;
use FindBin qw($Bin);

my $usage = qq{

  $0 <subject>  

  Copies data and generates a .m file for submission to SGE with runAmico.sh

};

if ($#ARGV < 0) {
  print $usage;
  exit 1;
}


my $subj = $ARGV[0];

my $appsDir = "/data/grossman/hcp/bin";

my $inputDir = "/data/grossman/hcp/subjectsPreProc/${subj}/T1w/Diffusion"; 

my $bvals = "${inputDir}/bvals";

my $bvecs = "${inputDir}/bvecs";

my $data = "${inputDir}/data.nii.gz";

my $mask = "${inputDir}/nodif_brain_mask.nii.gz";

my $amicoDataDir = "/data/grossman/hcp/amico/HCP_Lifespan/${subj}";

my $shells = "0,1500,3000";


system("mkdir -p $amicoDataDir");

system("cp $bvals ${amicoDataDir}/bvals");
system("cp $bvecs ${amicoDataDir}/bvecs");
system("cp $data ${amicoDataDir}/dwi.nii.gz");
system("gunzip ${amicoDataDir}/dwi.nii.gz");
system("cp $mask ${amicoDataDir}/brainMask.nii.gz");
system("gunzip ${amicoDataDir}/brainMask.nii.gz");

# check output exists
if (!( -f "${amicoDataDir}/bvals" && -f "${amicoDataDir}/bvecs" && -f "${amicoDataDir}/dwi.nii" && -f "${amicoDataDir}/brainMask.nii" )) {
  die("\n\tData import failed, missing required input in ${amicoDataDir}\n");
}

my $script = qq{ 

clearvars, clearvars -global, clc

addpath('$Bin');
addpath('${appsDir}/AMICO/matlab')

% Setup AMICO
AMICO_Setup

AMICO_SetSubject( 'HCP_Lifespan', '${subj}' )

CONFIG.dwiFilename    = fullfile( CONFIG.DATA_path, 'dwi.nii' );
CONFIG.maskFilename   = fullfile( CONFIG.DATA_path, 'brainMask.nii' );
CONFIG.schemeFilename = fullfile( CONFIG.DATA_path, 'amicoScheme.scheme' );

AMICO_fsl2scheme(fullfile( CONFIG.DATA_path, 'bvals' ), fullfile( CONFIG.DATA_path, 'bvecs' ), fullfile( CONFIG.DATA_path, 'amicoScheme.scheme') , [$shells])

% Load the dataset in memory
AMICO_LoadData

% Setup AMICO to use the 'NODDI' model
AMICO_SetModel( 'NODDI' );

% Generate the kernels corresponding to the protocol
AMICO_GenerateKernels( false );

% Resample the kernels to match the specific subject's scheme
AMICO_ResampleKernels();

AMICO_Fit()


};

open(my $fh, ">", "${amicoDataDir}/amicoModelFit.m");

print $fh $script;

close $fh; 
