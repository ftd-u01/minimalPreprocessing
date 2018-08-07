#!/usr/bin/perl -w


use strict;

use File::Spec;

my $usage = qq{

  $0 <dwi> <dwi_mask> <bvals> <bvecs> <outputDir>

  Copies data to output dir and unzips for Matlab 

  Generates outputDir/noddiScript.m file, which can be run directly

};

if ($#ARGV < 0) {
  print $usage;
  exit 1;
}



my ($dwi, $mask, $bvals, $bvecs, $outputDir) = @ARGV;

if (!( -f $dwi && -f $mask && -f $bvals && -f $bvecs )) {
  die("Required input missing");
}

$outputDir = File::Spec->rel2abs($outputDir);

# Got to unzip the data and mask for Matlab

# Matlab also has file name length restrictions so don't prepend everything 

system("cp $dwi ${outputDir}/dwi.nii.gz");

system("gunzip ${outputDir}/dwi.nii.gz");

system("cp $mask ${outputDir}/mask.nii.gz");

system("gunzip ${outputDir}/mask.nii.gz");

system("cp $bvals ${outputDir}/bvals");

system("cp $bvecs ${outputDir}/bvecs");

my $script = qq{ 

addpath(genpath(\'/data/grossman/hcp/bin/noddi\'))

NODDI_process(\'noddi\', \'dwi.nii\', \'mask.nii\', \'bvals\', \'bvecs\');

};

open(my $fh, ">", "${outputDir}/noddiScript.m");

print $fh $script;

close $fh; 
