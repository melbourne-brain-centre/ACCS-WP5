#This script is for ACCS workshop, and for using the script on your own research
#You should download your own shapeDNA license at http://reuter.mit.edu/software/shapedna/
# citing Reuter et al. (2006) 


#open the MASSIVE terminal and module load MATLAB, FreeSurfer
module load matlab

#open the matlab
matlab

#we will use matlab for the visualization purposes
#after opening the matlab, type the follwing code in the command window:

name='YOUR USER NAME' #write your user name inside the ''

cd (['/home/',name,'/oh21_scratch/',name,'/EM/scripts'])

#click the "ACCS_workshop_shape_analysis.m"

#after viewing the original white surface, we can generate the EV/EF.
#but in practical, we don't need to view the surface before generating EV/EF
#open a new Massive terminal and type the following code:

module load freesurfer/6.0

cd /home/${name}/oh21_scratch/${name}/EM/scripts

ID='100206'
SUBJECTS_DIR=/home/${name}/oh21_scratch/${name}/EM/Data
output=${SUBJECTS_DIR}/shape_output

mris_convert ${SUBJECTS_DIR}/${ID}/T1w/${ID}/surf/lh.white ${output}/lh.${ID}_white.vtk
#converting the mesh file to the vtk file

cd /home/${name}/oh21_scratch/${user}/EM/scripts

./shapeDNA-tria --mesh ${output}/lh.${ID}_white.vtk --num 200 --evec --ignorelq
#running shapeDNA 

python convert_ev_files.py -ev ${output}/lh.${ID}_white.vtk-r0-d1-nbc.ev -out ${output}/lh.${ID}_white;
#extracting EF/EV to tsv files
