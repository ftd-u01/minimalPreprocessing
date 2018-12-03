#!/usr/bin/perl -w

use strict;
use Cwd;
use File::Path;
use File::Spec;

my $inputBaseDir = "/data/grossman/hcp/subjectsPreProc";

my $usage = qq{

  $0 <subject>

  Where subject is the preprocessing subject ID in $inputBaseDir

  Structures raw nii data into the HCP format, ready for the pipelines

  The input is NIFTI data from

  ${inputBaseDir}/subject/rawNii

  and the output is

  ${inputBaseDir}/subject/unprocessed/3T

  Move any bad data out of the input directory before running this.

  

};

my $subject = "";


if (!($#ARGV + 1)) {
    print "$usage\n";
    exit 0;
}
else {

    ($subject) = @ARGV;

}

my $inputNiiDir = "${inputBaseDir}/${subject}/rawNii";

if (! -d $inputNiiDir ) {
  die "\n  Cannot find input directory $inputNiiDir \n\t";
}

my $outputBaseDir = "${inputBaseDir}/${subject}/unprocessed/3T";

if (! -d $outputBaseDir ) {
  mkpath($outputBaseDir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $outputBaseDir\n\t";
}

my @inputFiles = `ls $inputNiiDir | grep -P "(.nii.gz)|(.bval)|(.bvec)"`;

chomp @inputFiles;

# Some basic assumptions

# There ought to be three pairs of field maps

# The structural scans and rfmri1 use the first pair

# rfmri2 uses the second pair

# tasks use the third pair

# Structural scans are assumed to be acquired once, the second T1 or T2 is a bias-corrected version

# rfMRI is acquired as AP, then PA, and these go together. So we have rfmri1_AP, then rfmri1_PA, then rfmri2_AP, rfmri2_PA,
# with associated SBrefs.

# It's OK if the series numbers aren't sequential (something crashed and was reacquired)

# Will attempt to deal with partial data, but check results carefully if anything is not standard


# Parse files belonging to each modality
my @fieldMaps;

# Should be four runs total, each with SBref image
my @rfmri;

# Two files, first one is raw data, second one has pre scan normalization
my @t1 = ();
my @t2 = ();

# 98 and 99 with SBref and bvals / bvecs
my @diffusion;

# Gambling and WM tasks in both phase encodings
my @tfmriWM;
my @tfmriGambling;

# M0 and pCASL acquired separately, but we'll put them both in same array because they're both required
my @pcasl;


foreach my $inputFile (@inputFiles) {

    if ($inputFile =~ m/SpinEchoFieldMap_[AP]{2}.nii.gz/) {
	push(@fieldMaps, $inputFile);
    } 
    elsif ($inputFile =~ m/T1w_MPR.nii.gz/) {
        push(@t1, $inputFile);
    }
    elsif ($inputFile =~ m/T2w_SPC.nii.gz/) {
        push(@t2, $inputFile);
    }
    elsif ($inputFile =~ m/rfMRI_REST_[AP]{2}(_SBRef)?.nii.gz/) {
	push(@rfmri, $inputFile);
    }
    elsif ($inputFile =~ m/rfMRI_REST_[AP]{2}(_SBRef)?.nii.gz/) {
	push(@rfmri, $inputFile);
    }
    elsif ($inputFile =~ m/dMRI_dir9[89]_[AP]{2}.*/) {
	push(@diffusion, $inputFile);
    }
    elsif ($inputFile =~ m/tfMRI_WM_[AP]{2}.*/) {
	push(@tfmriWM, $inputFile);
    }
    elsif ($inputFile =~ m/tfMRI_GAMBLING_[AP]{2}.*/) {
	push(@tfmriGambling, $inputFile);
    }
    elsif ($inputFile =~ m/SPIRAL_V20_HCP_M0.nii.gz/) {
	push(@pcasl, $inputFile);
    }
    elsif ($inputFile =~ m/SPIRAL_V20_HCP_ASL.nii.gz/) {
	push(@pcasl, $inputFile);
    }
    else {
	print "\n Could not match $inputFile \n";
    }

}

# my @modalityDirs = qw/Diffusion rfMRI_REST1_AP rfMRI_REST1_PA rfMRI_REST2_AP rfMRI_REST2_PA T1w_MPR1 T2w_SPC1 tfMRI_GAMBLING_AP tfMRI_GAMBLING_PA tfMRI_WM_AP tfMRI_WM_PA/;

linkStructuralData($inputNiiDir, $subject, $outputBaseDir, "T1w_MPR", 1, 0, ($t1[0], @fieldMaps[0..1]));
linkStructuralData($inputNiiDir, $subject, $outputBaseDir, "T2w_SPC", 1, 0, ($t2[0], @fieldMaps[0..1]));

linkStructuralData($inputNiiDir, $subject, $outputBaseDir, "T1w_MPR", 1, 1, ($t1[1], @fieldMaps[0..1]));
linkStructuralData($inputNiiDir, $subject, $outputBaseDir, "T2w_SPC", 1, 1, ($t2[1], @fieldMaps[0..1]));


if (scalar(@diffusion) > 0) {
    linkDiffusionData($inputNiiDir, $subject, $outputBaseDir, @diffusion);
}

if (scalar(@rfmri) > 0) {
    linkRFMRIData($inputNiiDir, $subject, $outputBaseDir, 1, "AP", (@rfmri[0..1], @fieldMaps[0..1]));
    linkRFMRIData($inputNiiDir, $subject, $outputBaseDir, 1, "PA", (@rfmri[2..3], @fieldMaps[0..1]));
}

if (scalar(@rfmri) > 4) {
    linkRFMRIData($inputNiiDir, $subject, $outputBaseDir, 2, "AP", (@rfmri[4..5], @fieldMaps[2..3]));
    linkRFMRIData($inputNiiDir, $subject, $outputBaseDir, 2, "PA", (@rfmri[6..7], @fieldMaps[2..3]));
}

if (scalar(@tfmriGambling) > 0) {
    linkTFMRIData($inputNiiDir, $subject, $outputBaseDir, "tfMRI_GAMBLING", "AP", (@tfmriGambling[0..1], @fieldMaps[4..5]));
    linkTFMRIData($inputNiiDir, $subject, $outputBaseDir, "tfMRI_GAMBLING", "PA", (@tfmriGambling[2..3], @fieldMaps[4..5]));
}

if (scalar(@tfmriWM) > 0) {
    linkTFMRIData($inputNiiDir, $subject, $outputBaseDir, "tfMRI_WM", "AP", (@tfmriWM[0..1], @fieldMaps[4..5]));
    linkTFMRIData($inputNiiDir, $subject, $outputBaseDir, "tfMRI_WM", "PA", (@tfmriWM[2..3], @fieldMaps[4..5]));
}

if (scalar(@pcasl) > 0) {
    linkPCASLData($inputNiiDir, $subject, $outputBaseDir, @pcasl);
}

#
# linkDiffusionData($inputNiiDir, $subjectID, $outputBaseDir, @files)
# 
sub linkDiffusionData {

    my $cwd = getcwd();  

    my ($inputNiiDir, $subjectID, $outputBaseDir, @files) = @_;

    my $destDir = "${outputBaseDir}/Diffusion";

    if (! -d $destDir) {
      mkpath($destDir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $destDir\n\t";
    }
  
    chdir($destDir) or die "\n  Could not change directory to \n\n  " . rel2abs($destDir) . "\n\n";

    foreach my $file (@files) {

	my $outputFile = $file;

	$outputFile =~ s/^${subjectID}_[0-9]{4}/${subjectID}_3T/;

	my $relDir = File::Spec->abs2rel($inputNiiDir, $destDir);

	symlink("${relDir}/$file", $outputFile);

    }

    chdir($cwd) or die "\n  Could not change directory to \n\n  " . rel2abs($cwd) . "\n\n";
}


#
# linkRFMRIData($inputNiiDir, $subjectID, $outputBaseDir, $runNumber, $pe, @files)
# 
sub linkRFMRIData {

    my $cwd = getcwd();  

    my ($inputNiiDir, $subjectID, $outputBaseDir, $runNumber, $pe, @files) = @_;

    my $destDir = "${outputBaseDir}/rfMRI_REST${runNumber}_${pe}";

    if (! -d $destDir ) {
      mkpath($destDir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $destDir\n\t";
    }  

    chdir($destDir) or die "\n  Could not change directory to \n\n  " . rel2abs($destDir) . "\n\n";

    foreach my $file (@files) {

	my $outputFile = $file;

	if ($file =~ m/SpinEchoFieldMap/) {
	    $outputFile =~ s/^${subjectID}_[0-9]{4}/${subjectID}_3T/;
	} 
	else {
	    
	    # Don't want to accidentally invert the polarity
	    if (!$file =~ m/_${pe}(_SBRef)?\.nii\.gz/) {
		die "\n  Expected polarity $pe but file to link is $file\n\n";
	    }

	    $outputFile =~ s/^${subjectID}_[0-9]{4}_rfMRI_REST/${subjectID}_3T_rfMRI_REST${runNumber}/;
	}

	my $relDir = File::Spec->abs2rel($inputNiiDir, $destDir);

	symlink("${relDir}/$file", $outputFile);

    }

    chdir($cwd) or die "\n  Could not change directory to \n\n  " . rel2abs($cwd) . "\n\n";
}


#
# linkStructuralData($inputNiiDir, $subjectID, $outputBaseDir, $structuralName, $runNumber, $normalized, @files)
# 
sub linkStructuralData {

    my $cwd = getcwd();

    my ($inputNiiDir, $subjectID, $outputBaseDir, $structuralName, $runNumber, $normalized, @files) = @_;

    my $outputStructuralName = "${structuralName}${runNumber}";

    if ( $normalized ) {
      $outputStructuralName = "${outputStructuralName}_Norm";
    }

    my $destDir = "${outputBaseDir}/${outputStructuralName}";
    if (! -d $destDir ) {
      mkpath($destDir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $destDir\n\t";
    }
    chdir($destDir) or die "\n  Could not change directory to \n\n  " . rel2abs($destDir) . "\n\n";

    foreach my $file (@files) {

        my $outputFile = $file;

        if ($file =~ m/SpinEchoFieldMap/) {
            $outputFile =~ s/^${subjectID}_[0-9]{4}/${subjectID}_3T/;
        }
        else {
            $outputFile =~ s/^${subjectID}_[0-9]{4}_${structuralName}/${subjectID}_3T_${outputStructuralName}/;
        }

        my $relDir = File::Spec->abs2rel($inputNiiDir, $destDir);

        symlink("${relDir}/$file", $outputFile);

    }

    chdir($cwd) or die "\n  Could not change directory to \n\n  " . rel2abs($cwd) . "\n\n";
}


#
#  linkTFMRIData($inputNiiDir, $subjectID, $outputBaseDir, $taskName, $pe, @files)
# 
sub linkTFMRIData {

    my $cwd = getcwd();  

    my ($inputNiiDir, $subjectID, $outputBaseDir, $taskName, $pe, @files) = @_;

    my $destDir = "${outputBaseDir}/${taskName}_${pe}";

    if (! -d $destDir ) {
      mkpath($destDir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $destDir\n\t";
    }

    chdir($destDir) or die "\n  Could not change directory to \n\n  " . rel2abs($destDir) . "\n\t";

    foreach my $file (@files) {

	my $outputFile = $file;
	
	if ( !($file =~ m/SpinEchoFieldMap/ || $file =~ m/_${pe}(_SBRef)?\.nii\.gz/) ) {
	    die "\n  Expected polarity $pe but file to link is $file\n\n";
	}
	
	$outputFile =~ s/^${subjectID}_[0-9]{4}/${subjectID}_3T/;
	
	my $relDir = File::Spec->abs2rel($inputNiiDir, $destDir);

	symlink("${relDir}/$file", $outputFile);

    }

    chdir($cwd) or die "\n  Could not change directory to \n\n  " . rel2abs($cwd) . "\n\n";
}

#
# linkPCASLData($inputNiiDir, $subjectID, $outputBaseDir, @files)
# 
sub linkPCASLData {

    my $cwd = getcwd();  

    my ($inputNiiDir, $subjectID, $outputBaseDir, @files) = @_;

    my $destDir = "${outputBaseDir}/SPIRAL_V20_HCP_ASL";

    if (! -d $destDir ) {
      mkpath($destDir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $destDir\n\t";
    }

    chdir($destDir) or die "\n  Could not change directory to \n\n  " . rel2abs($destDir) . "\n\n";

    foreach my $file (@files) {

	my $outputFile = $file;

	$outputFile =~ s/^${subjectID}_[0-9]{4}/${subjectID}_3T/;

	my $relDir = File::Spec->abs2rel($inputNiiDir, $destDir);

	symlink("${relDir}/$file", $outputFile);

    }

    chdir($cwd) or die "\n  Could not change directory to \n\n  " . rel2abs($cwd) . "\n\n";
}



