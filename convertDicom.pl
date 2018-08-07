#!/usr/bin/perl -w

use strict;
use File::Path;

my $hcpBaseDir="/data/grossman/hcp";

# Where subject directories live, with dicom data
my $inputBaseDir = "${hcpBaseDir}/raw";

my $outputDicomBaseDir = "${hcpBaseDir}/subjectsDICOM";

my $outputNiiBaseDir = "${hcpBaseDir}/subjectsPreProc";

# Where things like ANTs and Pipedream live
my $binDir = "${hcpBaseDir}/bin";

my $usage = qq{

  $0 <subject> 

  Example: $0 techdev01

  Reorganizes data from 

    $inputBaseDir

  and converts to Nifti. After this script, run another script to link the
  nii files into a format suitable for the HCP pipelines.
 
  Note that HCP does not use our usual convention of subject/tp  

  TP is known to us but anonymized to the world. For internal use, we create 
  composite ids subj_tp.

  These are very large files so I recommend qlogin -l h_vmem=8G,s_vmem=8G to run this script

};

my $subject = "";

if (!($#ARGV + 1)) {
    print "$usage\n";
    exit 0;
}
else {

    ($subject) = @ARGV;

}


# Get the directories containing programs we need
my ($sysTmpDir) = $ENV{'TMPDIR'};

# Directory for temporary files 
my $tmpDir = "";

my $tmpDirBaseName = "${subject}hcpDicomToNifti";

if ( !($sysTmpDir && -d $sysTmpDir) ) {
    $tmpDir = "/tmp/${tmpDirBaseName}";
}
else {
    # Have system tmp dir
    $tmpDir = $sysTmpDir . "/${tmpDirBaseName}";
}

mkpath($tmpDir, {verbose => 0, mode => 0775}) or die "Cannot create working directory $tmpDir - maybe it exists from a previous run and needs to be deleted\n\t";

my $subjectDicomDir = "${outputDicomBaseDir}/${subject}";

# Followup scans should have a different subjectID
if (-d $subjectDicomDir) {
  print "\n Subject DICOM dir $subjectDicomDir exists, skipping DICOM conversion \n";
}
else {
  system("${binDir}/pipedream/dicom2series/dicom2series.sh ${subjectDicomDir} 1 0 ${inputBaseDir}/${subject}");
}

my @tps = `ls ${subjectDicomDir}`;

chomp @tps;    

# Now convert to nii
foreach my $timePoint (@tps) {
    
    my $outputSubjectID = "${subject}_${timePoint}";

    my $outputSubjectBaseDir = "${outputNiiBaseDir}/${outputSubjectID}";

    my $niiDir = "${outputSubjectBaseDir}/rawNii";
    
    if (-d ${niiDir}) {
	print "\n  Subject output directory $outputSubjectBaseDir exists, skipping this time point \n";
        next;
    }

    # Generate a protocol list for the subject
    my $protocolList =  "${tmpDir}/protocols.txt";

    system("ls ${subjectDicomDir}/${timePoint} | cut -d _ -f 2-100 | sort | uniq > $protocolList");

    print "\n  Converting series matching these names:\n\n";

    system("cat $protocolList");

    print "\n";

    system("${binDir}/pipedream/dicom2nii/dicom2nii.sh ${outputDicomBaseDir} $subject $timePoint $protocolList $niiDir");

    system("mkdir ${niiDir}/logs");

    system("mv $niiDir/*.txt ${niiDir}/logs");

}
