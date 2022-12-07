export NAME=trainer1

#### Webinar ACCS-Diffusion Data - 15 Nov 2022 ####

### Converting & Quality Check ###

# Converting nii input to mif (MRtrix format)

module load mrtrix/3.0.2

Input=~/oh21_scratch/${NAME}/Connectome/Data/Raw/Sub001

cd $Input/dwi

# Use mrconvert to combine the raw diffusion data with its corresponding .bvec and .bval files 

mrconvert Sub001_dwi.nii.gz Sub001_dwi.mif -fslgrad Sub001_dwi.bvec Sub001_dwi.bval

# cd ../rev_LR
# mrconvert Sub001_rev.nii.gz Sub001_rev.mif
# cp Sub001_rev.mif ../dwi/

############################################

# Visually CHECK

mrview Sub001_dwi.mif -mode 2

# Generate STD images to Check movement artifacts

dwiextract -no_bzero Sub001_dwi.mif - | mrmath -axis 3 - std Sub001_dwi_std.mif -force

dwiextract -bzero Sub001_dwi.mif - | mrmath -axis 3 - std Sub001_b0_std.mif -force

# Check the output
# Notice the high variability near the medial parts of the brainstem, cerebellum, and the lateral ventricles.

mrview Sub001_b0_std.mif -mode 2
mrview Sub001_dwi_std.mif -mode 2

###########################################################################################

### Preprocessing ###

#!/bin/bash

#SBATCH --job-name=Prep
# SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --account=oh21_scratch
#SBATCH --cpus-per-task=1
#SBATCH --gres=gpu:1
#SBATCH --partition=m3h
#SBATCH --mem-per-cpu=4000
#SBATCH -t 02:00:00


# Preprocessing with advanced slice-to-volume correction options

# Step_1: Denoising

dwidenoise Sub001_dwi.mif Sub001_den.mif -noise noise.mif

mrcalc Sub001_dwi.mif Sub001_den.mif -subtract residuals.mif

# Check Residuals, they should have no anatomical structure. 

mrview residuals.mif -mode 2    
 
# Gibbs ringing correction

mrdegibbs Sub001_den.mif Sub001_den_unring.mif

# Prior to Motion and Distortion Correction we need to extract the b0-volumes from the primary phase-encoded image (here is RL) and taking the mean

dwiextract -bzero Sub001_den_unring.mif Sub001_b0_RL.mif

mrmath Sub001_b0_RL.mif mean mean_b0_RL.mif -axis 3

# Important: the first half of catcatenation b0-pair image must be the mean-b0 from main phase-encoding direction, the second half must be the reverse-b0 image (if you have any reverse b0)

mrcat mean_b0_RL.mif Sub001_rev.mif -axis 3 Sub001_b0_pair.mif
mrview Sub001_b0_pair.mif -mode 2

##################### ====PAUSE ONE =====#################################
# This Step is very Time-Consuming (takes 1 hour), So we skip running this in workshop

# Make sure your slspec file starts from "0" as FSL only can read with assumption of starting slices with 0-number (interleaved acquisition)

# module load fsl/6.0.3
 
# dwifslpreproc Sub001_den_unring.mif Sub001_prep_eddy.mif -pe_dir RL -rpe_pair -se_epi Sub001_b0_pair.mif -readout_time 0.058 -eddy_slspec SliceOrder.txt -eddy_options " --repol --mporder=16 --s2v_niter=10 --s2v_lambda=5 --s2v_interp=trilinear "

# You can copy our preprocessed output from this directory: 

cp ~/oh21_scratch/${NAME}/Connectome/Data/Preprocess_done/Sub001_prep_eddy.mif ~/oh21_scratch/${NAME}/Connectome/Data/Raw/Sub001/dwi


####################### ===PAUSE ONE DONE=== #######################################

# BiasField Correction, removes field inhomogeneities

dwibiascorrect ants Sub001_prep_eddy.mif Sub001_prep_eddy_unbiased.mif -bias bias.mif

mrinfo Sub001_prep_eddy_unbiased.mif

###########################################################################################

### Response Function ###

# Estimate individual response functions using single-shell 3-tissue CSD (dhollander algorithm)

module purge
module load mrtrix3tissue/5.2.9

dwi2response dhollander Sub001_prep_eddy_unbiased.mif wm_resp1.txt gm_resp1.txt csf_resp1.txt -voxels ss3t_voxels.mif

# Check the outputs:
shview wm_resp1.txt
shview gm_resp1.txt 
shview csf_resp1.txt

##################### ====PAUSE Two =====#################################

# Group Averaged response functions (needed for quantative group analysis)
# Make a separate folder and take average across all subjects response functions and use this output for FOD generation in your real study

# Estimate group average response functions (for individual 3-tissues wm, gm and csf)
# responsemean wm_resp.txt group_ave_resp_wm.txt 
# responsemean gm_resp.txt group_ave_resp_gm.txt 
# responsemean csf_resp.txt group_ave_resp_csf.txt

###########################################################################################

### Brain Extraction ###

cd ../T1/

/usr/local/kul_vbg/20201103/kul_vbg-20201103-venv/bin/hd-bet -i Sub001_T1.nii.gz -o Sub001_T1_brain.nii.gz -tta 0 -mode fast -s 1 -device cpu

# Visualization:

module load fsl/6.0.3
slicesdir -o Sub001_T1.nii.gz Sub001_T1_brain.nii.gz 
firefox / here copy your html output link

###########################################################################################

### Upsampling DWI and Generating Brain Mask ###

# Upsampling DWI from 2.5 resolution upto 1.3 (better results)

cd ../dwi

mrgrid Sub001_prep_eddy_unbiased.mif regrid Sub001_prep_upsampled.mif -voxel 1.3 
mrinfo Sub001_prep_upsampled.mif

mrconvert Sub001_prep_upsampled.mif Sub001_prep_upsampled.nii.gz

cp Sub001_prep_upsampled.nii.gz ../T1/ 

cd ../T1/

# Coregistering T1 to dwi-upsampled space

flirt -in Sub001_T1.nii.gz -ref Sub001_prep_upsampled.nii.gz -out T1-corg-dwi.nii.gz -omat invol2refvol.mat -dof 6

flirt -in Sub001_T1_brain_mask.nii.gz -ref Sub001_prep_upsampled.nii.gz -out Sub001_prep_upsampled_mask.nii.gz -init invol2refvol.mat -applyxfm


fslmaths Sub001_prep_upsampled_mask.nii.gz -bin Sub001_prep_upsampled_mask_bin.nii.gz
mrconvert Sub001_prep_upsampled_mask_bin.nii.gz Sub001_prep_upsampled_mask_bin.mif
cp Sub001_prep_upsampled_mask_bin.mif ../dwi/

# Check the output mask

vglrun fsleyes Sub001_prep_upsampled.nii.gz Sub001_prep_upsampled_mask_bin.nii.gz

#############################====PAUSE Three =====##############################

# Computing FOD (Fibre Orientation Distribution) maps using CSD(Constrained Spherical Deconvolution) modeling , takes 45mins

# cd ../dwi

# ss3t_csd_beta1 Sub001_prep_upsampled.mif /group_ave_resp_wm.txt wmfod.mif.gz /group_ave_resp_gm.txt gm.mif.gz /group_ave_resp_csf.txt csf.mif.gz -mask Sub001_prep_upsampled_mask_bin.mif 

# Perform joint bias field correction and global intensity normalisation

# mtnormalise wmfod.mif.gz Sub001_wmfod_norm.mif.gz gm.mif.gz Sub001_gm_norm.mif.gz csf.mif.gz Sub001_csf_norm.mif.gz -mask Sub001_prep_upsampled_mask_bin.mif

# You can copy our FOD-normalized output from this directory:

cp ~/oh21_scratch/${NAME}/Connectome/Data/FOD_done/Sub001_wmfod_norm.mif.gz ~/oh21_scratch/${NAME}/Connectome/Data/Raw/Sub001/dwi/
cp ~/oh21_scratch/${NAME}/Connectome/Data/FOD_done/Sub001_gm_norm.mif.gz ~/oh21_scratch/${NAME}/Connectome/Data/Raw/Sub001/dwi/
cp ~/oh21_scratch/${NAME}/Connectome/Data/FOD_done/Sub001_csf_norm.mif.gz ~/oh21_scratch/${NAME}/Connectome/Data/Raw/Sub001/dwi/

#############################====PAUSE Three Done =====##############################
# Check the FOD Outputs

# To view these FODs, we will combine them into a single image. First we extract the first b0 volume. Then, this is used as the input into an mrcat command which combines the FOD images from all three tissue types into a single image (vf.mif).

cd ../dwi

mrconvert -coord 3 0 Sub001_wmfod_norm.mif.gz - | mrcat Sub001_csf_norm.mif.gz Sub001_gm_norm.mif.gz - vf.mif.gz

mrview vf.mif.gz -odf.load_sh Sub001_wmfod_norm.mif.gz

# Green= represents GM tissue, Red= CSF, Blue= shows WM
# Direction-Colour => Red: X-axis / Green: Y-axis /Blue: Z-axis

#############################################################

### Registering T1 to DWI Space ####

# Extracting Upsampled b0 & applying brain-mask 

mrconvert -coord 3 0 Sub001_prep_upsampled.mif Sub001_b0_upsampled.nii.gz 

mrcalc Sub001_b0_upsampled.nii.gz Sub001_prep_upsampled_mask_bin.mif -mul Sub001_b0_upsampled_brain.nii.gz 

cp Sub001_b0_upsampled_brain.nii.gz ../T1

cd ../T1

# Segment white matter using fast , less than 5 mins
# output of interest is seg_pve_2.nii.gz

fast -o Sub001_T1_seg.nii.gz -g Sub001_T1_brain.nii.gz

fslmaths Sub001_T1_seg_pve_2.nii.gz -thr 0.5 -bin Sub001_T1_wmseg.nii.gz


# Register b0 to T1 using flirt (boundary-based registration)

flirt -in Sub001_b0_upsampled_brain.nii.gz -ref Sub001_T1_brain.nii.gz -dof 6 -omat b02anat_xform.mat 

flirt -in Sub001_b0_upsampled_brain.nii.gz -ref Sub001_T1_brain.nii.gz -dof 6 -cost bbr -wmseg Sub001_T1_wmseg.nii.gz -init b02anat_xform.mat -omat b02anat_bbr.mat -schedule $FSLDIR/etc/flirtsch/bbr.sch


# Transform the flirt matrix to MRtrix format
transformconvert b02anat_bbr.mat Sub001_b0_upsampled_brain.nii.gz Sub001_T1_brain.nii.gz flirt_import b02anat_bbr_mrtrixformat.txt 

# Apply (inverse) transform matrix to T1 image for FreeSurfer (with whole head for FS >> give anat2b0.nii to FS)
mrtransform Sub001_T1.nii.gz -linear b02anat_bbr_mrtrixformat.txt Sub001_anat2b0.nii.gz -inverse 

# Apply (inverse) transform matrix to T1_brain image for 5ttgen (with only brain >> give brain2b0.nii.gz for 5tt)
mrtransform Sub001_T1_brain.nii.gz -linear b02anat_bbr_mrtrixformat.txt Sub001_brain2b0.nii.gz -inverse 

# Check the Outputs:
# vglrun fsleyes Sub001_prep_upsampled.nii.gz Sub001_anat2b0.nii.gz
vglrun fsleyes Sub001_b0_upsampled_brain.nii.gz Sub001_brain2b0.nii.gz

###########################################################################################

### 5 Tissue Type Segmentation for ACT ###
# Generating a five-tissue-type segmented tissue image suitable for use in Anatomically-Constrained Tractography (ACT), takes 5mins

5ttgen fsl Sub001_brain2b0.nii.gz Sub001_5tt.nii.gz -premasked

# Check the output:

vglrun fsleyes Sub001_5tt.nii.gz

################################====PAUSE Four =====###################################

### FreeSurfer Preprocessing ###

# We skip this step as it will take 7 hours or more !

# cd ../T1

# recon-all -i /Sub001_anat2b0.nii.gz -s Sub001 -sd $outputdir -all

# You can copy our FreeSurfer output folder from this directory: 

cp -r ~/oh21_scratch/${NAME}/Connectome/Data/FreeSurfer_done ~/oh21_scratch/${NAME}/Connectome/Data/Raw/Sub001/T1/

###################################====PAUSE Four Done=====####################################


################################====PAUSE Five =====###################################

### ACT Tractography ### 

# We skip this step as it may take couple of hours

# cd ../dwi

# tckgen -step 1 -angle 45 -maxlength 250 -minlength 2.6 -cutoff 0.07 -act ../T1/Sub001_5tt.nii.gz -backtrack -crop_at_gmwmi -seed_dynamic Sub001_wmfod_norm.mif.gz -select 20M Sub001_wmfod_norm.mif.gz Sub001_wb_1st_45_fod07_act_20M.tck


### SIFT2 ### 
             
# tcksift2 Sub001_wb_1st_45_fod07_act_1M.tck Sub001_wmfod_norm.mif.gz Sub001_sift2_weights.csv -act ../T1/Sub001_5tt.nii.gz -out_mu Sub001_sift2_mu.txt -out_coeffs sift2_coeffs.txt

# You can copy our ACT and SIFT2 outputs from this directory: 

cp ~/oh21_scratch/${NAME}/Connectome/Data/ACT_done/Sub001_wb_1st_45_fod07_act_20M.tck ~/oh21_scratch/${NAME}/Connectome/Data/Raw/Sub001/dwi/
cp ~/oh21_scratch/${NAME}/Connectome/Data/ACT_done/Sub001_sift2_weights.csv ~/oh21_scratch/${NAME}/Connectome/Data/Raw/Sub001/dwi/
cp ~/oh21_scratch/${NAME}/Connectome/Data/ACT_done/Sub001_sift2_mu.txt ~/oh21_scratch/${NAME}/Connectome/Data/Raw/Sub001/dwi/

################################====PAUSE Five Done =====###################################
# Check results of ACT

cd ../dwi

tckedit Sub001_wb_1st_45_fod07_act_20M.tck wb_100k.tck -number 100k

mrview Sub001_b0_upsampled_brain.nii.gz -tractography.load wb_100k.tck -overlay.load Sub001_wmfod_norm.mif.gz -overlay.load ../T1/Sub001_5tt.nii.gz
 

################################====PAUSE Six =====###################################

### Parcellations ###

# Loading modules:

# module load mrtrix3tissue/5.2.8
# module load freesurfer/6.0
# module unload virtualgl/2.5.2
# module load virtualgl/2.5.0

# labelconvert ../T1/FreeSurfer_done/Sub001/mri/aparc+aseg.mgz /usr/local/freesurfer/6.0/FreeSurferColorLUT.txt /usr/local/mrtrix3tissue/5.2.8/MRtrix3Tissue/share/mrtrix3/labelconvert/fs_default.txt Sub001_nodes.mif

# Replacing the sub-cortical grey matter delineations using FSL FIRST

# labelsgmfix -premasked Sub001_nodes.mif ../T1/Sub001_brain2b0.nii.gz /usr/local/mrtrix3tissue/5.2.8/MRtrix3Tissue/share/mrtrix3/labelconvert/fs_default.txt Sub001_Parcellations_fixed.mif

# You can copy our Parcellations from this directory: 

cp ~/oh21_scratch/${NAME}/Connectome/Data/Nodes_done/Sub001_Parcellations_fixed.mif ~/oh21_scratch/${NAME}/Connectome/Data/Raw/Sub001/dwi/

################################====PAUSE Six Done =====###################################
# Check the output

mrconvert Sub001_Parcellations_fixed.mif Sub001_Parcellations_fixed.nii

vglrun fsleyes Sub001_Parcellations_fixed.nii

###########################################################################################

### Connectome ###


tck2connectome -symmetric -zero_diagonal -scale_invnodevol -tck_weights_in Sub001_sift2_weights.csv Sub001_wb_1st_45_fod07_act_20M.tck Sub001_Parcellations_fixed.mif Sub001_Connectome_fixed.csv -out_assignment Sub001_assignments_fixed.csv

###########################################################################################

### Visualizing Connectivity Matrix ###:

# Should plot a connectivity matrix of 84 x 84 size

module load matlab/r2019b
matlab
Con=readmatrix('Sub001_Connectome_fixed.csv');
figure; imagesc(Con)
figure; imagesc(log(Con))
figure; histogram(Con)

#####################################

# Extra: Color-coded wmFOD:

# fod2dec Sub001_wmfod_norm.mif.gz decfod.mif -mask Sub001_prep_upsampled_mask_bin.mif
# mrview decfod.mif -odf.load_sh Sub001_wmfod_norm.mif.gz -mode 2

######################################
