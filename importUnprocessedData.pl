#!/usr/bin/perl -w

use strict;
use Cwd;
use File::Copy;
use File::Path;
use File::Spec;
use Getopt::Long;

my $inputBaseDir = "/data/grossman/hcp/subjectsPreProc";

# Reads Nifti headers faster than ANTs
my $readNiiExe = "/data/grossman/hcp/bin/camino/bin/niftiheader -readheader";

my $quarantineTruncated = 1;

my $forceOutput = 0;

my $usage = qq{

  $0 --subject <subject> [options]

  Where subject is the preprocessing subject ID in $inputBaseDir

  Structures raw nii data into the HCP format, ready for the pipelines

  The input is NIFTI data from

  ${inputBaseDir}/subject/rawNii

  and the output is

  ${inputBaseDir}/subject/unprocessed/3T

  The script can attempt to assist identifying and quarantining truncated data.
  Data that is complete but unusable (eg due to motion) needs to be identified and quarantined before 
  running this script.


  Options:

  --quarantine-truncated
    Attempt to identify data that has the wrong number of volumes; this is often why data is
    re-acquired (default = $quarantineTruncated). 

  --force 
    Force output to be produced even though there are possible errors. Use carefully and check output 
    (default = $forceOutput).


};

my $subject = "";

if (!($#ARGV + 1)) {
    print "$usage\n";
    exit 1;
}


GetOptions("subject=s" => \$subject,
	   "quarantine-truncated=i" => \$quarantineTruncated,
	   "force=i" => \$forceOutput
    )
    or die("Error in command line arguments\n");


my $inputNiiDir = "${inputBaseDir}/${subject}/rawNii";

if (! -d $inputNiiDir ) {
  die "\n  Cannot find input directory $inputNiiDir \n\t";
}

my @inputFiles = `ls $inputNiiDir | grep -P "(.nii.gz)|(.bval)|(.bvec)"`;

chomp(@inputFiles);

if ($quarantineTruncated) {
    # Call quarantine function here
    quarantineIfTruncated($inputNiiDir, @inputFiles);

    # Now re-list the input dir to get files that are still there
    @inputFiles = `ls $inputNiiDir | grep -P "(.nii.gz)|(.bval)|(.bvec)"`;

    chomp(@inputFiles);

}

# Some basic assumptions

# There ought to be three pairs of field maps

# The structural scans and rfmri1 use the first pair

# rfmri2 uses the second pair

# tasks use the third pair

# Structural scans are assumed to be acquired once, the second T1 or T2 is a bias-corrected version

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

# Containing the ASL and the M0
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
    elsif ($inputFile =~ m/dMRI_dir9[89]_[AP]{2}.*/) {
	push(@diffusion, $inputFile);
    }
    elsif ($inputFile =~ m/tfMRI_WM_[AP]{2}(_SBRef)?.nii.gz/) {
	push(@tfmriWM, $inputFile);
    }
    elsif ($inputFile =~ m/tfMRI_GAMBLING_[AP]{2}(_SBRef)?.nii.gz/) {
	push(@tfmriGambling, $inputFile);
    }
    elsif ($inputFile =~ m/SPIRAL_V20_HCP_M0.nii.gz/) {
	push(@pcasl, $inputFile);
    }
    elsif ($inputFile =~ m/SPIRAL_V20_HCP_ASL.nii.gz/) {
	push(@pcasl, $inputFile);
    }
    else {
        # Ignore scouts, etc
	# print "\n Could not match $inputFile \n";
    }

}

# Return non-zero if there's any problems
my $exitCode = 0;

# Some basic checks that the right files will get linked

my $expectedNumFieldMaps = 6;

my $numFieldMaps = scalar(@fieldMaps);

if ($numFieldMaps != $expectedNumFieldMaps) {
    print "\n  WARNING: Expected $expectedNumFieldMaps spin echo field maps but found " . $numFieldMaps . "\n";
    $exitCode = 1;
} 

# Check that field maps are in AP / PA pairs
for (my $i = 0; $i < $numFieldMaps / 2; $i++) {
    my $fieldMapString = join(" ", @fieldMaps[($i * 2)..($i * 2 + 1)]);

    if (!($fieldMapString =~ m/SpinEchoFieldMap_AP.nii.gz/ && $fieldMapString =~ m/SpinEchoFieldMap_AP.nii.gz/)) {
	print "\n  ERROR: Spin echo field map polarity is not paired \n";
	$exitCode = 1;
    }
}


# One T1 + one bias-corrected version
my $expectedNumT1 = 2;

if (scalar(@t1) != $expectedNumT1) {
    print "\n  WARNING: Expected $expectedNumT1 T1 images  but found " . scalar(@t1) . "\n";
    $exitCode = 1;
}

# One T2 + one bias-corrected version
my $expectedNumT2 = 2;

if (scalar(@t2) != $expectedNumT2) {
    print "\n  WARNING: Expected $expectedNumT2 T2 images  but found " . scalar(@t2) . "\n";
    $exitCode = 1;
}


# Diffusion data

# Check we have the right number of files. Should be 
# dir98_*.nii.gz 4 
# dir98_*.b*     4 
# dir99_*.nii.gz 4 
# dir99_*.b*     4 
# Total          16
my $expectedNumDiffusionFiles = 16;

my $diffusionString = join(" ", @diffusion);

if (scalar(@diffusion) != $expectedNumDiffusionFiles) {
    print "\n  WARNING: Expected $expectedNumDiffusionFiles DWI image, bvec, bval files but found " . scalar(@diffusion) . "\n";
    $exitCode = 1;
}

foreach my $shells (qw/dir98 dir99/) {
    
    # Check the data exists in each polarity
    
    foreach my $polarity (qw/AP PA/) {
	if ( !($diffusionString =~ m/dMRI_${shells}_${polarity}_SBRef.nii.gz/) ) {
	    print "\n  ERROR : Missing diffusion SBRef image for ${shells} ${polarity} \n";
	    $exitCode = 1;
	}
	if ( !($diffusionString =~ m/dMRI_${shells}_${polarity}.nii.gz/) ) {
	    print "\n  ERROR : Missing diffusion data for ${shells} ${polarity} \n";
	    $exitCode = 1;
	}
	if ( !($diffusionString =~ m/dMRI_${shells}_${polarity}.bval/) ) {
	    print "\n  ERROR : Missing diffusion bval for ${shells} ${polarity} \n";
	    $exitCode = 1;
	}
	if ( !($diffusionString =~ m/dMRI_${shells}_${polarity}.bvec/) ) {
	    print "\n  ERROR : Missing diffusion bvec for ${shells} ${polarity} \n";
	    $exitCode = 1;
	}
    }
}

# rfMRI data

# Expect 2 sets of scans, AP, PA, total 8 images

my $expectedNumRFMRIImages = 8;

my $rfmriString = join(" ", @rfmri);

if (scalar(@rfmri) != $expectedNumRFMRIImages) {
    print "\n  WARNING: Expected $expectedNumRFMRIImages rfMRI images but found " . scalar(@rfmri) . "\n";
    $exitCode = 1;
}

# Check we have the same number of AP and PA rfMRI data

my $numFMRISBRefImagesAP = () = $rfmriString =~ m/AP_SBRef.nii.gz/g;
my $numFMRISBRefImagesPA = () =  $rfmriString =~ m/PA_SBRef.nii.gz/g;
my $numFMRIImagesAP = () = $rfmriString =~ m/AP.nii.gz/g;
my $numFMRIImagesPA = () = $rfmriString =~ m/PA.nii.gz/g;

if (!( $numFMRISBRefImagesAP == $numFMRISBRefImagesPA && $numFMRISBRefImagesAP == $numFMRIImagesAP 
       && $numFMRIImagesAP == $numFMRIImagesPA )) {
    print "\n  ERROR: Number of complete PA, AP rfMRI series is unbalanced\n";
    $exitCode = 1;
}

# Check tfMRI

my $tfmriString = join(" ", @tfmriGambling, @tfmriWM);

my $expectedNumTFMRIImages = 8;

my $numTFMRIImages = scalar(@tfmriGambling) + scalar(@tfmriWM);

if ( $numTFMRIImages != $expectedNumTFMRIImages ) {
    print "\n  WARNING: Expected $expectedNumTFMRIImages tfMRI images but found $numTFMRIImages \n";
    $exitCode = 1;
}

foreach my $task (qw/WM GAMBLING/) { 
    for my $polarity (qw/AP PA/) {
	if ( !($tfmriString =~ m/tfMRI_${task}_${polarity}_SBRef.nii.gz/) ) {
	    print "\n  WARNING : Missing tfMRI SBRef image for ${task} ${polarity} \n";
	    $exitCode = 1;
	}
	if ( !($tfmriString =~ m/tfMRI_${task}_${polarity}.nii.gz/) ) {
	    print "\n  WARNING : Missing tfMRI data for ${task} ${polarity} \n";
	    $exitCode = 1;
	}
    }
}

# Check PCASL
my $numExpectedASLImages = 2;

# Some sites just don't acquire ASL, so don't complain if there's nothing
if (scalar(@pcasl) > 0 && scalar(@pcasl) != $numExpectedASLImages) {
    print "\n  WARNING: Expected $numExpectedASLImages PCASL images but found " . scalar(@pcasl) . "\n";
    $exitCode = 1;
}

if ( ($exitCode > 0) && ($forceOutput == 0) ) {
    print "\n  Data may not be correct, exiting \n";
    exit $exitCode;
}

my $outputBaseDir = "${inputBaseDir}/${subject}/unprocessed/3T";

if (! -d $outputBaseDir) {
    mkpath($outputBaseDir, {verbose => 0, mode => 0775}) or die "Cannot create output directory $outputBaseDir\n\t";
}

$exitCode = linkStructuralData($inputNiiDir, $subject, $outputBaseDir, "T1w_MPR", 1, 0, ($t1[0], @fieldMaps[0..1]));
$exitCode = linkStructuralData($inputNiiDir, $subject, $outputBaseDir, "T2w_SPC", 1, 0, ($t2[0], @fieldMaps[0..1]));

$exitCode = linkStructuralData($inputNiiDir, $subject, $outputBaseDir, "T1w_MPR", 1, 1, ($t1[1], @fieldMaps[0..1]));
$exitCode = linkStructuralData($inputNiiDir, $subject, $outputBaseDir, "T2w_SPC", 1, 1, ($t2[1], @fieldMaps[0..1]));


if (scalar(@diffusion) > 0) {
    $exitCode = linkDiffusionData($inputNiiDir, $subject, $outputBaseDir, @diffusion);
}


if (scalar(@rfmri) > 1) {
    $exitCode = linkRFMRIData($inputNiiDir, $subject, $outputBaseDir, 1, (@rfmri[0..1], @fieldMaps[0..1]));
}
if (scalar(@rfmri) > 3) {
    $exitCode = linkRFMRIData($inputNiiDir, $subject, $outputBaseDir, 1, (@rfmri[2..3], @fieldMaps[0..1]));
}
if (scalar(@rfmri) > 5) {
    $exitCode = linkRFMRIData($inputNiiDir, $subject, $outputBaseDir, 2, (@rfmri[4..5], @fieldMaps[2..3]));
}
if (scalar(@rfmri) > 7) {
    $exitCode = linkRFMRIData($inputNiiDir, $subject, $outputBaseDir, 2, (@rfmri[6..7], @fieldMaps[2..3]));
}

if (scalar(@tfmriGambling) > 1) {
    $exitCode = linkTFMRIData($inputNiiDir, $subject, $outputBaseDir, "tfMRI_GAMBLING", (@tfmriGambling[0..1], @fieldMaps[4..5]));
}
if (scalar(@tfmriGambling) > 3) {
    $exitCode = linkTFMRIData($inputNiiDir, $subject, $outputBaseDir, "tfMRI_GAMBLING", (@tfmriGambling[2..3], @fieldMaps[4..5]));
}
    
if (scalar(@tfmriWM) > 1) {
    $exitCode = linkTFMRIData($inputNiiDir, $subject, $outputBaseDir, "tfMRI_WM", (@tfmriWM[0..1], @fieldMaps[4..5]));
}
if (scalar(@tfmriWM) > 3) {
    $exitCode = linkTFMRIData($inputNiiDir, $subject, $outputBaseDir, "tfMRI_WM", (@tfmriWM[2..3], @fieldMaps[4..5]));
}

if (scalar(@pcasl) > 1) {
    $exitCode = linkPCASLData($inputNiiDir, $subject, $outputBaseDir, @pcasl);
}

exit $exitCode;

#
# linkDiffusionData($inputNiiDir, $subjectID, $outputBaseDir, @files)
# 
sub linkDiffusionData {

    my $cwd = getcwd();  

    my ($inputNiiDir, $subjectID, $outputBaseDir, @files) = @_;

    my $destDir = "${outputBaseDir}/Diffusion";

    if ( ! mkpath($destDir, {verbose => 0, mode => 0775}) ) {
      print "  Cannot create output directory $destDir\n";
      return 1;
    }
    
    chdir($destDir) or die "\n  Could not change directory to \n\n  " . rel2abs($destDir) . "\n\n";

    foreach my $file (@files) {

        if (!($file && -f "${inputNiiDir}/${file}")) {
            print "\n  WARNING: Missing diffusion data for\n\t${destDir}\n\n";
            next;
        }

	my $outputFile = $file;

	$outputFile =~ s/^${subjectID}_[0-9]{4}/${subjectID}_3T/;

	my $relDir = File::Spec->abs2rel($inputNiiDir, $destDir);

	symlink("${relDir}/$file", $outputFile);

    }

    chdir($cwd) or die "\n  Could not change directory to \n\n  " . rel2abs($cwd) . "\n\n";

    return 0;
}


#
# linkRFMRIData($inputNiiDir, $subjectID, $outputBaseDir, $runNumber, @files)
# 
sub linkRFMRIData {

    my $cwd = getcwd();  

    my ($inputNiiDir, $subjectID, $outputBaseDir, $runNumber, @files) = @_;

    # Detect polarity from first input file, then ensure consistency
    ($files[0] =~ m/rfMRI_REST_([AP]{2})(_SBRef)?.nii.gz/) or die "\n  Input file $files[0] does not match as rfMRI sequence\n"; ;

    my $polarity = $1;

    my $destDir = "${outputBaseDir}/rfMRI_REST${runNumber}_${polarity}";

    if ( ! mkpath($destDir, {verbose => 0, mode => 0775}) ) {
      print "  Cannot create output directory $destDir\n";
      return 1;
    }
    
    chdir($destDir) or die "\n  Could not change directory to \n\n  " . rel2abs($destDir) . "\n\n";

    foreach my $file (@files) {

        if (!($file && -f "${inputNiiDir}/${file}")) {
            print "\n  WARNING: Missing rfMRI data or field maps for\n\t${destDir}\n\n";
            next;
        }

	my $outputFile = $file;

	if ($file =~ m/SpinEchoFieldMap/) {
	    $outputFile =~ s/^${subjectID}_[0-9]{4}/${subjectID}_3T/;
	} 
	else {
	    
	    # Don't want to accidentally invert the polarity
	    if (!$file =~ m/_${polarity}(_SBRef)?\.nii\.gz/) {
		die "\n  Expected polarity $polarity but file to link is $file\n\n";
	    }

	    $outputFile =~ s/^${subjectID}_[0-9]{4}_rfMRI_REST/${subjectID}_3T_rfMRI_REST${runNumber}/;
	}

	my $relDir = File::Spec->abs2rel($inputNiiDir, $destDir);

	symlink("${relDir}/$file", $outputFile);

    }

    chdir($cwd) or die "\n  Could not change directory to \n\n  " . rel2abs($cwd) . "\n\n";

    return 0;
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

    if ( ! mkpath($destDir, {verbose => 0, mode => 0775}) ) {
      print "  Cannot create output directory $destDir\n";
      return 1;
    }

    chdir($destDir) or die "\n  Could not change directory to \n\n  " . rel2abs($destDir) . "\n\n";

    foreach my $file (@files) {

        if (!($file && -f "${inputNiiDir}/${file}")) {
            print "\n  WARNING: Missing structural data or field maps for\n\t${destDir}\n\n";
            next;
        }

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

    return 0;
}


#
#  linkTFMRIData($inputNiiDir, $subjectID, $outputBaseDir, $taskName, @files)
# 
sub linkTFMRIData {

    my $cwd = getcwd();  

    my ($inputNiiDir, $subjectID, $outputBaseDir, $taskName, @files) = @_;

    # Detect polarity from first input file, then ensure consistency
    ($files[0] =~ m/${taskName}_([AP]{2})(_SBRef)?.nii.gz/) or die "\n  Input file $files[0] does not match as $taskName sequence \n";

    my $polarity = $1;

    my $destDir = "${outputBaseDir}/${taskName}_${polarity}";

    if ( ! mkpath($destDir, {verbose => 0, mode => 0775}) ) {
      print "  Cannot create output directory $destDir\n";
      return 1;
    }
    
    chdir($destDir) or die "\n  Could not change directory to \n\n  " . rel2abs($destDir) . "\n\t";

    foreach my $file (@files) {

        if (!($file && -f "${inputNiiDir}/${file}")) {
            print "\n  WARNING: Missing tfMRI data or field maps for\n\t${destDir}\n\n";
            next;
        }

	my $outputFile = $file;
	
	if ( !($file =~ m/SpinEchoFieldMap/ || $file =~ m/_${polarity}(_SBRef)?\.nii\.gz/) ) {
	    die "\n  Expected polarity $polarity but file to link is $file\n\n";
	}
	
	$outputFile =~ s/^${subjectID}_[0-9]{4}/${subjectID}_3T/;
	
	my $relDir = File::Spec->abs2rel($inputNiiDir, $destDir);

	symlink("${relDir}/$file", $outputFile);

    }

    chdir($cwd) or die "\n  Could not change directory to \n\n  " . rel2abs($cwd) . "\n\n";

    return 0;
}



#
# linkPCASLData($inputNiiDir, $subjectID, $outputBaseDir, @files)
# 
sub linkPCASLData {

    my $cwd = getcwd();  

    my ($inputNiiDir, $subjectID, $outputBaseDir, @files) = @_;

    my $destDir = "${outputBaseDir}/SPIRAL_V20_HCP_ASL";

    if ( ! mkpath($destDir, {verbose => 0, mode => 0775}) ) {
      print "  Cannot create output directory $destDir\n";
      return 1;
    }
    
    chdir($destDir) or die "\n  Could not change directory to \n\n  " . rel2abs($destDir) . "\n\n";

    foreach my $file (@files) {

        if (!($file && -f "${inputNiiDir}/${file}")) {
            print "\n  WARNING: Missing ASL data for\n\t${destDir}\n\n";
            next;
        }

	my $outputFile = $file;

	$outputFile =~ s/^${subjectID}_[0-9]{4}/${subjectID}_3T/;

	my $relDir = File::Spec->abs2rel($inputNiiDir, $destDir);

	symlink("${relDir}/$file", $outputFile);

    }

    chdir($cwd) or die "\n  Could not change directory to \n\n  " . rel2abs($cwd) . "\n\n";

    return 0;
}


#
# Checks all 4D data and moves to ${inputNiiDir}/quarantine if it is truncated.
#
# If the number of volumes is incorrect, the image associated files (sbref, bvecs, etc) will be quarantined. 
#
# It's almost always the case that the number of volumes is reduced, but data will be quarantined if it is too long.
# An additional warning is generated in this case.
#
#
# quarantineIfTruncated($inputDir, @inputFiles).
#
sub quarantineIfTruncated {

    my ($inputDir, @inputFiles) = @_;

    
    # Check all 4D data for size; remove those with fewer volumes than expected
    my $rfmriNumVolumes = 420;
    my $dmri98NumVolumes = 99;
    my $dmri99NumVolumes = 100;
    my $tfmriWMNumVolumes = 365;
    my $tfmriGamblingNumVolumes = 228;
    my $aslNumVolumes = 29;
    
    foreach my $inputFile (@inputFiles) {
	if ($inputFile =~ m/_([0-9]{4})_rfMRI_REST_([AP]{2}).nii.gz/) {
	    my $seriesNumber = $1;
	    my $polarity = $2;

	    my $sbRefSeriesNumber = sprintf("%04d", $seriesNumber - 1);
	    
	    my $sbRef = $inputFile;

	    $sbRef =~ s/${seriesNumber}_rfMRI_REST_${polarity}/${sbRefSeriesNumber}_rfMRI_REST_${polarity}_SBRef/;

	    my @filesToMove = ($inputFile, $sbRef);

	    moveIfTruncated($inputDir, $rfmriNumVolumes, @filesToMove);
	}
	elsif ($inputFile =~ m/_([0-9]{4})_dMRI_dir98_([AP]{2}).nii.gz/) {
	  
	    my $seriesNumber = $1;
	    my $polarity = $2;

	    my $sbRefSeriesNumber = sprintf("%04d", $seriesNumber - 1);
	    
	    my $sbRef = $inputFile;

	    $sbRef =~ s/${seriesNumber}_dMRI_dir98_${polarity}/${sbRefSeriesNumber}_dMRI_dir98_${polarity}_SBRef/;

	    my @filesToMove = ($inputFile, $sbRef);

	    # Check for bvals / bvecs
	    my $bvals = $inputFile;
	    my $bvecs = $inputFile;
	    
	    $bvals =~ s/\.nii\.gz/\.bval/;
	    
	    $bvecs =~ s/\.nii\.gz/\.bvec/;

	    if (-f "${inputDir}/${bvals}") {
		push(@filesToMove, $bvals);
	    }
	    if (-f "${inputDir}/${bvecs}") {
		push(@filesToMove, $bvecs);
	    }

	    moveIfTruncated($inputDir, $dmri98NumVolumes, @filesToMove);
	}
	elsif ($inputFile =~ m/_([0-9]{4})_dMRI_dir99_([AP]{2}).nii.gz/) {
	  
	    my $seriesNumber = $1;
	    my $polarity = $2;

	    my $sbRefSeriesNumber = sprintf("%04d", $seriesNumber - 1);
	    
	    my $sbRef = $inputFile;

	    $sbRef =~ s/${seriesNumber}_dMRI_dir99_${polarity}/${sbRefSeriesNumber}_dMRI_dir99_${polarity}_SBRef/;

	    my @filesToMove = ($inputFile, $sbRef);

	    # Check for bvals / bvecs
	    my $bvals = $inputFile;
	    my $bvecs = $inputFile;
	    
	    $bvals =~ s/\.nii\.gz/\.bval/;
	    $bvecs =~ s/\.nii\.gz/\.bvec/;

	    if (-f "${inputDir}/${bvals}") {
		push(@filesToMove, $bvals);
	    }
	    if (-f "${inputDir}/${bvecs}") {
		push(@filesToMove, $bvecs);
	    }

	    moveIfTruncated($inputDir, $dmri99NumVolumes, @filesToMove);
	}
	elsif ($inputFile =~ m/_([0-9]{4})_tfMRI_WM_([AP]{2}).nii.gz/) {
	    
	    my $seriesNumber = $1;
	    my $polarity = $2;
	    
	    my $sbRefSeriesNumber = sprintf("%04d", $seriesNumber - 1);
	    
	    my $sbRef = $inputFile;
	    
	    $sbRef =~ s/${seriesNumber}_tfMRI_WM_${polarity}/${sbRefSeriesNumber}_tfMRI_WM_${polarity}_SBRef/;
	    
	    my @filesToMove = ($inputFile, $sbRef);

	    moveIfTruncated($inputDir, $tfmriWMNumVolumes, @filesToMove);
	}
	elsif ($inputFile =~ m/_([0-9]{4})_tfMRI_GAMBLING_([AP]{2}).nii.gz/) {
	    
	    my $seriesNumber = $1;
	    my $polarity = $2;
	    
	    my $sbRefSeriesNumber = sprintf("%04d", $seriesNumber - 1);
	    
	    my $sbRef = $inputFile;
	    
	    $sbRef =~ s/${seriesNumber}_tfMRI_GAMBLING_${polarity}/${sbRefSeriesNumber}_tfMRI_GAMBLING_${polarity}_SBRef/;
	    
	    my @filesToMove = ($inputFile, $sbRef);

	    moveIfTruncated($inputDir, $tfmriGamblingNumVolumes, @filesToMove);

	}
	elsif ($inputFile =~ m/_([0-9]{4})_SPIRAL_V20_HCP_ASL.nii.gz/) {

	    my $seriesNumber = $1;

	    
	    # series - 1 : SPIRAL_V20_HCP_M0.nii.gz
	    # series + 1 : SPIRAL_V20_HCP_MeanPerf.nii.gz

	    my $m0SeriesNumber = sprintf("%04d", $seriesNumber - 1);

	    my $meanPerfSeriesNumber = sprintf("%04d", $seriesNumber + 1);
	    
	    my $m0 = $inputFile;
	    
	    $m0 =~ s/${seriesNumber}_SPIRAL_V20_HCP_ASL/${m0SeriesNumber}_SPIRAL_V20_HCP_M0/;

	    my $meanPerf = $inputFile;
	    
	    $meanPerf =~ s/${seriesNumber}_SPIRAL_V20_HCP_ASL/${meanPerfSeriesNumber}_SPIRAL_V20_HCP_MeanPerf/;
	    
	    my @filesToMove = ($inputFile, $m0, $meanPerf);

	    moveIfTruncated($inputDir, $aslNumVolumes, @filesToMove);

	}

    }

}

#
# Helper function to check and quarantine truncated data
#
# moveIfTruncated($inputDir, $expectedNumVolumes, @filesToMove)
#
# The first file $filesToMove[0] should be the time series to check. If it has the wrong
# number of volumes, all files in the array get moved.
#
sub moveIfTruncated {

    my ($inputDir, $expectedNumVolumes, @filesToMove) = @_;
    
    my $timeSeries = $filesToMove[0];

    my $dimString = `$readNiiExe ${inputDir}/$timeSeries | grep --text "Dataset dimensions" | cut -d : -f 2`; 

    chomp($dimString); 

    $dimString =~ s/^\s+//;
    $dimString =~ s/\s+$//;

    my @dims = split(" ", $dimString);

    if ($dims[0] < 4) {
	# 4D data with one volume is saved as a 3D nifti image
	$dims[4] = 1;
    }

    if ($dims[4] != $expectedNumVolumes) {
	# Quarantine
	my $quarantineDir = "${inputDir}/quarantine";
	
	if (! -d $quarantineDir) {
	    mkpath($quarantineDir, {verbose => 0, mode => 0775}) or die "Cannot create directory $quarantineDir\n\t";
	}

	print "\n  Time series $filesToMove[0] has $dims[4] volumes, expected $expectedNumVolumes.\n  Quarantining:\n" . join("\n", @filesToMove) . "\n";
	
	foreach my $moving (@filesToMove) {
	    move("${inputDir}/${moving}", $quarantineDir);
	}
    }
    
    # Shouldn't happen but just in case
    if ($dims[4] > $expectedNumVolumes) {
	print "\n  ERROR: $timeSeries has $dims[4] volumes, GREATER than expected $expectedNumVolumes\n";
    }
}

