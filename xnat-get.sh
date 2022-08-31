#!/bin/bash
# This script downloads dicom from XNAT and converta them to nifti using dcm2niix
# Nifti files will be named and organised according to BIDS

# If you havent used xnat-utils before, please load module on your terminal
# It will ask for your log-in details
# Once you've logged on, the module will remember your credentials
# and will allow you to download scans at any time.
# If your password changes you must re-enter your details by loading xnat (module load xnat-utils)
# then enter an xnat function with your authcate username at the end ie. xnat-ls --user <authcate>
# You can then re-enter and save your password.

# BIDS file naming convention:
# t1: sub-000_T1w.nii.gz
# dwi: sub-000_dwi.nii.gz
# rs-fmri: sub-000_task-rest_bold.nii.gz 
# task fmri multiple runs: sub-000_task-nback_run-01_bold.nii.gz
# if you have controls/patients: sub-control000_task-rest_bold.nii.gz / sub-patient000_task-rest_bold.nii.gz
# Accompanying .json files will be created by dcm2niix
# edited by Suzan Maleki and Yu-Chi Chen at Monash University 

# The study you'd like to download; you should change it accordingly
# This is just an example
STUDY=MRH108_
SESSION=_MR01

# You should change the path where the subject list sits
SUBJIDS=$(SUBJECT_PATH/subject_list.txt)

# Your project paths on MASSIVE
PROJDIR=/home/ychen/kg98_scratch/Yuchi/xnat_test
DICOMDIR=$PROJDIR/dicomdir
RAWDATADIR=$PROJDIR/rawdata

if [ ! -d $PROJDIR ]; then mkdir $PROJDIR; echo "making directory"; fi
if [ ! -d $DICOMDIR ]; then mkdir $DICOMDIR; echo "making directory"; fi
if [ ! -d $RAWDATADIR ]; then mkdir $RAWDATADIR; echo "making directory"; fi

# These variables is based on the name of your project and scans on XNAT
# After running this script, please check whether all scans are there
# If they are missing, go back on XNAT and see if the scans are named differently
# !! No whitespace,if so, access to change it

ANATOMICAL=t1_mprage_sag_p2_iso_1_ADNI
FUNCTIONAL=Resting_ep2d_p2_3mm
TASKFMRIRUN1=ep2d_p2_3mm_479_RUN_1
TASKFMRIRUN2=ep2d_p2_3mm_479_RUN_2
MTROFF=MTR_fl3d_tra_MT_Off_IPat2_4_iso
MTRON=MTR_fl3d_tra_MT_On_IPat2_4_iso

# load modules
module purge;
module load xnat-utils;
# Load the dcm2niix software
module load mricrogl/1.0.20170207
# Module toggles (on/off)
	MODULE1=1 #dcm2niix

# create for loop to loop over IDs
for ID in $SUBJIDS; do 
	
	# Dynamic directories
	SUBDICOMDIR=$DICOMDIR/sub-$ID
	OUTDIR=$RAWDATADIR/sub-$ID;
	EPIOUTDIR=$OUTDIR/func;
	T1OUTDIR=$OUTDIR/anat;
        TASKOUTDIR1=$OUTDIR/task1;
        TASKOUTDIR2=$OUTDIR/task2;
        MTROUTON=$OUTDIR/mtrON;
        MTROUTOFF=$OUTDIR/mtrOFF;

	# Create subject's DICOMS folders 
	mkdir -p $SUBDICOMDIR/

	# Download structural scans from XNAT
	cd $SUBDICOMDIR/; xnat-get $STUDY$ID$SESSION --scans $ANATOMICAL;

	# Download resting state scans from XNAT
	cd $SUBDICOMDIR/; xnat-get $STUDY$ID$SESSION --scans $FUNCTIONAL;
         
        # Download task fMRI scans run 1 from XNAT
        cd $SUBDICOMDIR/; xnat-get $STUDY$ID$SESSION --scans $TASKFMRIRUN1;
        
        # Download task fMRI scans run 2 from XNAT
        cd $SUBDICOMDIR/; xnat-get $STUDY$ID$SESSION --scans $TASKFMRIRUN2;

        # Download MTRON scans from XNAT
	cd $SUBDICOMDIR/; xnat-get $STUDY$ID$SESSION --scans $MTRON;

        # Download MTROFF scans from XNAT
	cd $SUBDICOMDIR/; xnat-get $STUDY$ID$SESSION --scans $MTROFF;

	# Delete intermediate folders
	mv $SUBDICOMDIR/$STUDY$ID$SESSION/* $SUBDICOMDIR

	rm -rf $SUBDICOMDIR/$STUDY$ID$SESSION


	# rename scan directories with more reasonable naming conventions

	# t1
	if [ -d "${SUBDICOMDIR/*$ANATOMICAL}" ]; then 
		mv $SUBDICOMDIR/*$ANATOMICAL $SUBDICOMDIR/t1; 
	else 
		echo "No t1 scan for $ID"; 
	fi
        
        #rfMRI
        if [ -d "${SUBDICOMDIR/*$FUNCTIONAL}" ]; then
                mv $SUBDICOMDIR/*$FUNCTIONAL $SUBDICOMDIR/rfMRI;
        else
                echo "No rfMRI scan for $ID";
        fi

        #taskfMRI1
        if [ -d "${SUBDICOMDIR/*$FUNCTIONAL}" ]; then
                mv $SUBDICOMDIR/*$FUNCTIONAL $SUBDICOMDIR/taskfMRI1;
        else
                echo "No taskfMRI1 scan for $ID";
        fi

        #taskfMRI2
        if [ -d "${SUBDICOMDIR/*$FUNCTIONAL}" ]; then
                mv $SUBDICOMDIR/*$FUNCTIONAL $SUBDICOMDIR/taskfMRI2;
        else
                echo "No taskfMRI2 scan for $ID";
        fi

        # MTRON
        if [ -d "${SUBDICOMDIR/*$MTRON}" ]; then mv $SUBDICOMDIR/*$MTRON $SUBDICOMDIR/MTRon; 
        else 
		echo "No MTRON scan for $ID"; 
        fi

        # MTROFF
        if [ -d "${SUBDICOMDIR/*$MTROFF}" ]; then mv $SUBDICOMDIR/*$MTROFF $SUBDICOMDIR/MTRoff; 
        else 
		echo "No MTROFF scan for $ID"; 
        fi

	# populate rawdata dir with subjects folders

	if [ ! -d $OUTDIR ]; then mkdir $OUTDIR; echo "$ID - making directory"; fi
	if [ ! -d $EPIOUTDIR ]; then mkdir $EPIOUTDIR; echo "$ID - making func directory"; fi
	if [ ! -d $T1OUTDIR ]; then mkdir $T1OUTDIR; echo "$ID - making anat directory"; fi
        if [ ! -d $TASKOUTDIR1 ]; then mkdir $TASKOUTDIR1; echo "$ID - making task1 directory"; fi
        if [ ! -d $TASKOUTDIR2 ]; then mkdir $TASKOUTDIR2; echo "$ID - making task2 directory"; fi
        if [ ! -d $MTROUTON ]; then mkdir $MTROUTON; echo "$ID - making MTRON directory"; fi
        if [ ! -d $MTROUTOFF ]; then mkdir $MTROUTOFF; echo "$ID - making MTROFF directory"; fi

	################################ MODULE 1: dcm2niix convert #######################################

	if [ $MODULE1 = "1" ]; then
		echo -e "\nRunning MODULE 1: dcm2niix $ID \n"
		
		# t1
		dcm2niix -f "sub-"$ID"_T1w" -o $T1OUTDIR -b -m n -z y $SUBDICOMDIR"/t1/"

		# fMRI epi
		dcm2niix -f "sub-"$ID"_task-rest_bold" -o $EPIOUTDIR -b -m n -z y $SUBDICOMDIR"/rfMRI/"
                
                # task fMRI run1 
                dcm2niix -f "sub-"$ID"_ses-1_task-RL_bold" -o $TASKOUTDIR1 -b -m -z y $SUBDICOMDIR"/taskfMRI1"
                 
                # task fMRI run2
                dcm2niix -f "sub-"$ID"_ses-1_task-RL_bold" -o $TASKOUTDIR2 -b -m -z y $SUBDICOMDIR"/taskfMRI2"

                # MTRON
		dcm2niix -f "sub-"$ID"_mtr-ON" -o $MTROUTON -b -m n -z y $SUBDICOMDIR"/MTRon/"

                # MTROFF
		dcm2niix -f "sub-"$ID"_mtr-OFF" -o $MTROUTOFF -b -m n -z y $SUBDICOMDIR"/MTRoff/"

		
		echo -e "\nFinished MODULE 1: dcm2niix convert: $ID \n"
	else
		echo -e "\nSkipping MODULE 1: dcm2niix convert: $ID \n"
	fi

	###################################################################################################


done
