#!/bin/bash

#
# Usage
#=====================================================
usage="${0} <func> <T1> <output directory> [physiolog]"

printStatus() {
    printf \\e[36m"\tFunc: ${1}\n"
}

printWarning() {
    printf \\e[31m"\tFunc: ${1}\n"
}


if [ ${#} -lt 3 ]; then
    echo ${usage}
    exit
fi

if [ -e /usr/local/lib ]
then
    printWarning "You may need to run 'sudo mv /usr/local/lib /usr/local/lib.save' if you encounter errors."
    sleep 10
    #exit 1
fi


#
# Define Variables
#=====================================================

inFunc=${1}
inT1=${2}

echo $inFunc

preprocDir=${3}
echo $preprocDir

T1Dir=`dirname ${preprocDir}`/T1Proc
compCorDesignDir=${preprocDir}/CompCorDesign
motionDesignDir=${preprocDir}/MotionDesign

cd "`dirname "${0}"`"
echo "current dir: "`pwd`
scriptDir=`pwd`


#
# Make directories
#=====================================================
if [ ! -d ${preprocDir} ]; then
    printStatus "Making dir ${preprocDir}"
    mkdir -p ${preprocDir}
fi

if [ ! -d ${compCorDesignDir} ]; then
    printStatus "Making dir ${compCorDesignDir}"
    mkdir -p ${compCorDesignDir}
fi

if [ ! -d ${motionDesignDir} ]; then
    printStatus "Making dir ${motionDesignDir}"
    mkdir -p ${motionDesignDir}
fi

if [ ! -d ${T1Dir} ]; then
    printStatus "Making dir ${T1Dir}"
    mkdir -p ${T1Dir}
fi

stdOut=${preprocDir}/Output.txt
stdErr=${preprocDir}/Errors.txt
echo -en "\n\n-------------`date`---------------\n\n" >> ${stdOut}
echo -en "\n\n-------------`date`---------------\n\n" >> ${stdErr}


#
# Process T1
#=====================================================
"${scriptDir}/T1_process.sh" ${inT1} ${T1Dir} "${scriptDir}" &
T1Proc_ID=${!}

#
# Copy data and reorient
#=====================================================
if [ ! -e ${preprocDir}/func.nii.gz ]; then
    fslreorient2std ${inFunc} ${preprocDir}/func.nii.gz >>${stdOut} 2>>${stdErr}
    printStatus "func oriented"
fi

if [ ${#} -eq 4 ]; then
    inLog=${4}
    cp ${inLog} ${preprocDir}/ScanPhysLog.txt
    inLog=ScanPhysLog.txt
    printStatus "physio ok"
else
    inLog=""
fi

cd ${preprocDir}


inFunc=func.nii.gz
fslroi $inFunc example_func 96 1


#
# Mask brain in functional scan
#=====================================================
if [ ! -e ${inFunc%.nii.gz}_masked.nii.gz ]; then
    bet ${inFunc} ${inFunc%.nii.gz}_masked.nii.gz -F >>${stdOut} 2>>${stdErr}
    fslroi ${inFunc%.nii.gz}_masked.nii.gz ${inFunc%.nii.gz}_masked_3d.nii.gz 0 1
    slicesmask ${inFunc%.nii.gz}_masked_3d.nii.gz ${inFunc} func_brain.png &
fi
inFunc=${inFunc%.nii.gz}_masked.nii.gz


#
# Make movie of functional scan
#=====================================================
if [ ! -e ${inFunc%.nii.gz}.mp4 ]; then
    "${scriptDir}/makeMovie.sh" ${inFunc} ${inFunc%.nii.gz} >>${stdOut} 2>>${stdErr} &
fi

#
# Get functional file info
#=====================================================
info=`fslinfo func.nii.gz`
nVols=`echo ${info} | awk '{print $10}'`
nVols=`echo "${nVols} - 1" | bc`
tr=`echo ${info} | awk '{print $20}'`

echo "nb volumes: " ${nVols}
echo "tr: " ${tr}


##full linear and non-linear registration
###############################################################
if [[ ! -d ${preprocDir}/reg ]]; then
  mkdir -p ${preprocDir}/reg
fi

#check T1 is betted already. If not, call T1_process script
#T1dir=$(ls -d /Volumes/Pain_lab_data/IDP/derivative/${subj}/func/T1Proc)
#T1dir=${inputdir}/func/T1Proc

#if brain has noot been segmented and betted, do so now
# if [ ! -d ${T1dir} ]; then
#       printStatus "starting T1 processing script"
#       mkdir ${T1dir}
#       scriptDir=/usr/local/bin/cchmc_MRI_scripts/ProcessingScripts_TCM/
#       echo $scriptDir
#       #inT1=`/Volumes/Pain_lab_data/IDP/derivative/${subj}/anat/o*avg*.nii.gz`
#       inT1=${inputdir}/anat/o*avg*.nii.gz
#       echo $inT1
#       ${scriptDir}/T1_process.sh ${inT1} ${T1dir} ${scriptDir} T1Proc_ID=${!}
# fi
#           # echo $(ls ${outputDir})
# pwd
cp example_func.nii.gz reg/

# prep/rename structural files

fslmaths ${T1Dir}/anat_brain.nii.gz ${preprocDir}/reg/T1brain
fslmaths ${T1Dir}/anat.nii.gz ${preprocDir}/reg/T1head
fslmaths ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz ${preprocDir}/reg/standard
fslmaths ${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz ${preprocDir}/reg/standard_head
fslmaths ${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask_dil.nii.gz ${preprocDir}/reg/standard_mask

#register func to highres/anat
cd ${preprocDir}/reg/

printStatus "performing registration func to anatomical"

epi_reg --epi=example_func --t1=T1head --t1brain=T1brain --out=example_func2highres

convert_xfm -inverse -omat highres2example_func.mat example_func2highres.mat

slicer example_func2highres T1brain -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; /usr/local/fsl/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres1.png ; /usr/local/fsl/bin/slicer T1brain example_func2highres -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; /usr/local/fsl/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres2.png ; /usr/local/fsl/bin/pngappend example_func2highres1.png - example_func2highres2.png example_func2highres.png; /bin/rm -f sl?.png example_func2highres2.png

rm example_func2highres1.png

#register highres/anat to standard
printStatus "performing registration anatomical to standard"

flirt -in T1brain -ref standard -out highres2standard -omat highres2standard.mat -cost corratio -dof 12 -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -interp trilinear

fnirt --iout=highres2standard_head --in=T1head --aff=highres2standard.mat --cout=highres2standard_warp --iout=highres2standard --jout=highres2highres_jac --config=T1_2_MNI152_2mm --ref=standard_head --refmask=standard_mask --warpres=10,10,10

applywarp -i T1brain -r standard -o highres2standard -w highres2standard_warp

convert_xfm -inverse -omat standard2highres.mat highres2standard.mat

slicer highres2standard standard -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; /usr/local/fsl/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard1.png ; /usr/local/fsl/bin/slicer standard highres2standard -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; /usr/local/fsl/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard2.png ; /usr/local/fsl/bin/pngappend highres2standard1.png - highres2standard2.png highres2standard.png; /bin/rm -f sl?.png highres2standard2.png

rm highres2standard1.png

convert_xfm -omat example_func2standard.mat -concat highres2standard.mat example_func2highres.mat

convertwarp --ref=standard --premat=example_func2highres.mat --warp1=highres2standard_warp --out=example_func2standard_warp

applywarp --ref=standard --in=example_func --out=example_func2standard --warp=example_func2standard_warp

convert_xfm -inverse -omat standard2example_func.mat example_func2standard.mat

slicer example_func2standard standard -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; /usr/local/fsl/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard1.png ; /usr/local/fsl/bin/slicer standard example_func2standard -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; /usr/local/fsl/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard2.png ; /usr/local/fsl/bin/pngappend example_func2standard1.png - example_func2standard2.png example_func2standard.png; /bin/rm -f sl?.png example_func2standard2.png

rm example_func2standard1.png

cd ${preprocDir}

#
# Normalization
#=====================================================
#echo "Perform Normalization"
#if [ ! -e ${T1Dir}/highres2standard.mat ]; then
#    flirt -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -in ${T1Dir}/anat_ss.nii.gz -out ${T1Dir}/highres2standard -omat ${T1Dir}/highres2standard.mat &
#    flirtID2=${!}
#fi

#
# retroicor
#=====================================================
# if [ ! -e retroicor.nii.gz ]; then
# if [ ${#} -eq 4 ]; then
#     #Process scan physLog
#     printStatus "3dretroicor"
#     cardiacLog=ScanPhysLog_cardiac.txt
#     respirationLog=ScanPhysLog_respiration.txt
#     cardiacthresh=$((python33 ${scriptDir}/../PhysioLogs/PhysLogParser.py -i ${inLog} -f ${inFunc} -out_cardiac ${cardiacLog} -out_resp ${respirationLog})2>&1)
#     printWarning "Cardiac Threshold: " ${cardiacthresh}
#     fsl_tsplot -i ScanPhysLog_cardiac.txt -o cardiac.png --title="Cardiac Signal" -w 2000 -h 144 &
#     fsl_tsplot -i ScanPhysLog_respiration.txt -o respiration.png --title="Respiration Signal" -w 900 -h 144 &
#     3dretroicor -card ${cardiacLog} -cardphase cardiacPhase -resp ${respirationLog} -respphase respPhase -threshold $cardiacthresh -order 2 SliceTimingCorrection.nii.gz >>${stdOut} 2>>${stdErr}
#     3dAFNItoNIFTI retroicor+orig.BRIK >>${stdOut} 2>>${stdErr}
#     fsl_tsplot -i cardiacPhase -o cardiac_phase.png --title="Cardiac Phase" -w 2000 -h 144 &
#     fsl_tsplot -i respPhase -o respiration_phase.png --title="Respiration Phase" -w 900 -h 144 &
#     gzip retroicor.nii
#     currentFunc=retroicor.nii.gz
# else
#     currentFunc=SliceTimingCorrection.nii.gz
# fi
#
# fi

#
# Motion correction
#=====================================================
if [ ! -e rrest.nii.gz ]; then
    printStatus "Perform Volume registration"
    mcflirt -in ${inFunc} -out rrest -meanvol -stats -mats -plots -report -rmsrel -rmsabs -spline_final >>${stdOut} 2>>${stdErr}
    currentFunc=rrest.nii.gz
    motionCorrID=${!}
#    echo "current func: " ${currentFunc}
fi

wait ${motionCorrID}
#
# Motion plots
#=====================================================
if [ ! -e rotation.png ]; then
    printStatus "Motion plots"
    fsl_tsplot -i rrest.par -o rotation.png --start=1 --finish=3 --title='Rotations (radians)' -a x,y,z -w 640 -h 144 &
    fsl_tsplot -i rrest.par -o translation.png --start=4 --finish=6 --title='Translations (mm)' -a x,y,z -w 640 -h 144 &
    fsl_tsplot -i rrest_abs.rms,rrest_rel.rms -t 'MCFLIRT estimated mean displacement (mm)' -u 1 -w 640 -h 144 -a absolute,relative -o disp.png
fi

#wait ${T1Proc_ID}
#
# Co-registration
#=====================================================
if [ ! -e example_func2highres.mat ]; then
    printStatus "Perform Co-registration"
    flirt -ref ${T1Dir}/anat_ss.nii.gz -in rrest_mean_reg.nii.gz -out example_func2highres.nii.gz -omat example_func2highres.mat >>${stdOut} 2>>${stdErr} &
    flirtID1=${!}

fi

wait ${flirtID1} #${flirtID2}

#
# Outlier detection
#=====================================================
if [ ! -e outliers.txt ]; then
    printStatus "Outlier detection"
    fsl_motion_outliers -i ${inFunc} -o outliers.txt -p outliers.png >>${stdOut} 2>>${stdErr} &
    outlierID=${!}
fi

wait ${outlierID}
#
# Concatenate transformation matrices
#=====================================================
if [ ! -e example_func2standard.mat ]; then
    convert_xfm -omat example_func2standard.mat -concat ${T1Dir}/highres2standard.mat example_func2highres.mat >>${stdOut} 2>>${stdErr}
    convert_xfm -omat highres2func.mat -inverse example_func2highres.mat >>${stdOut} 2>>${stdErr}
fi

#
# Slice timing correction
#=====================================================
if [ ! -e SliceTimingCorrection.nii.gz ]; then
    printStatus "Slice timing correction"
    slicetimer -i ${currentFunc} -o SliceTimingCorrection.nii.gz -r ${tr} >>${stdOut} 2>>${stdErr} &
    currentFunc=SliceTimingCorrection.nii.gz
    sliceTimingID=${!}
fi

wait ${sliceTimingID}

#run bet2
###################################################################
printStatus "betting and creating mask for func"
fslmaths ${currentFunc} -Tmean mean_func
bet2 mean_func mask -f 0.3 -n -m; immv mask_mask mask
fslmaths ${currentFunc} -mas mask prefiltered_func_data_bet
thresh=$( fslstats prefiltered_func_data_bet -p 98 )
echo ${thresh}
thresh10=$(echo "$thresh / 10" | bc -l)
fslmaths prefiltered_func_data_bet -thr ${thresh10}  -Tmin -bin mask -odt char
med_perc=$(fslstats ${currentFunc} -k mask -p 50)
echo ${med_perc}
perc2=$(fslstats ${currentFunc} -k mask -p 2)
echo ${perc2}
bt_thresh=$(echo "($med_perc - $perc2) * 0.75" | bc -l)
fslmaths mask -dilF mask
fslmaths ${currentFunc} -mas mask prefiltered_func_data_thresh
fslmaths prefiltered_func_data_thresh -Tmean mean_func
currentFunc=prefiltered_func_data_thresh.nii.gz


#spatial smoothing
#######################################################
printStatus "spatial smoothing in process"
susan ${currentFunc} ${bt_thresh} 2.12314225053 3 1 1 mean_func ${bt_thresh} prefiltered_func_data_smooth
fslmaths prefiltered_func_data_smooth -mas mask prefiltered_func_data_smooth
normmean=10000
scaling=$(echo "$normmean / $med_perc" | bc -l)
fslmaths prefiltered_func_data_smooth -mul $scaling prefiltered_func_data_intnorm
fslmaths prefiltered_func_data_intnorm -Tmean tempMean

#high pass filtering
###############################################################
printStatus "high pass filtering with cutoff at 100s"
fslmaths prefiltered_func_data_intnorm -bptf 25.0 -1 -add tempMean prefiltered_func_data_tempfilt
imrm tempMean
fslmaths prefiltered_func_data_tempfilt filtered_func_data
currentFunc=filtered_func_data.nii.gz
#echo "current func: " ${preprocDir} "/" ${currentFunc}
#cd ${outputDir}
fslmaths ${currentFunc} -Tmean mean_func


#
# Normalize functional file
#=====================================================
if [ ! -e rrest_mni.nii.gz ]; then
    python3 "${scriptDir}/align4D_2023.py" ${currentFunc} ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz example_func2standard.mat rrest_mni.nii.gz >>${stdOut} 2>>${stdErr}
    # normalizID=${!}
fi

# wait ${normalizID}

#
# Compcor/Friston 24 calculations
#=====================================================
if [ ! -e ${preprocDir}/CompCorDesign/rrest_CSF_PCA09.png ]; then
    printStatus "Calculate Principal Components"
    ### Compcor ###
    cd CompCorDesign
    #echo "current dir: " `pwd`
    #Bring Anatomical WM and CSF masks to functional space (use nearest neighbor interpolation
    flirt -ref ${preprocDir}/rrest_mean_reg.nii.gz -in ${T1Dir}/seg_pve_0_thr95_eroded_masked.nii.gz -interp nearestneighbour -out seg_pve_0_CSF_thr95_eroded_masked_inFunc -applyxfm -init ${preprocDir}/highres2func.mat >>${stdOut} 2>>${stdErr}
    flirt -ref ${preprocDir}/rrest_mean_reg.nii.gz -in ${T1Dir}/seg_pve_2_thr95_eroded_masked.nii.gz -interp nearestneighbour -out seg_pve_2_WM_thr95_eroded_masked_inFunc -applyxfm -init ${preprocDir}/highres2func.mat >>${stdOut} 2>>${stdErr}
    slices ${preprocDir}/rrest_mean_reg.nii.gz seg_pve_0_CSF_thr95_eroded_masked_inFunc.nii.gz -o seg_pve_0_CSF_thr95_eroded_inFunc.png >>${stdOut} 2>>${stdErr}
    slices ${preprocDir}/rrest_mean_reg.nii.gz seg_pve_2_WM_thr95_eroded_masked_inFunc.nii.gz -o seg_pve_2_WM_thr95_eroded_inFunc.png >>${stdOut} 2>>${stdErr}

    # Calculate principal components from WM Mask
    3dpc -mask seg_pve_2_WM_thr95_eroded_masked_inFunc.nii.gz -pcsave 10 -prefix rrest_WM_PCA ${preprocDir}/${currentFunc} >>${stdOut} 2>>${stdErr}
    for i in `seq 0 9`; do
        3dAFNItoNIFTI -prefix rrest_WM_PCA_${i}.nii rrest_WM_PCA+orig[${i}] >>${stdOut} 2>>${stdErr}
        fslmaths rrest_WM_PCA_${i}.nii -mul -1 rrest_WM_PCA_${i}_neg.nii.gz >>${stdOut} 2>>${stdErr}
        overlay 0 0 ${preprocDir}/rrest.nii.gz -a rrest_WM_PCA_${i}.nii.gz 100 1000 rrest_WM_PCA_${i}_neg.nii.gz 100 1000 rrest_WM_PCA_${i}_overlay >>${stdOut} 2>>${stdErr}
        fslroi rrest_WM_PCA_${i}_overlay rrest_WM_PCA_${i}_overlay_3d 0 1
        slicer rrest_WM_PCA_${i}_overlay_3d -S 1 400 rrest_WM_PCA_${i}_overlay.png >>${stdOut} 2>>${stdErr}
        rm -f rrest_WM_PCA_${i}_neg.nii.gz
        fsl_tsplot -i rrest_WM_PCA0${i}.1D -o rrest_WM_PCA0${i}.png -w 2000 -h 144
    done


    # Calculate principal components from CSF Mask
    3dpc -mask seg_pve_0_CSF_thr95_eroded_masked_inFunc.nii.gz -pcsave 10 -prefix rrest_CSF_PCA ../${currentFunc} >>${stdOut} 2>>${stdErr}
    for i in `seq 0 9`; do
        3dAFNItoNIFTI -prefix rrest_CSF_PCA_${i}.nii rrest_CSF_PCA+orig[${i}] >>${stdOut} 2>>${stdErr}
        fslmaths rrest_CSF_PCA_${i}.nii -mul -1 rrest_CSF_PCA_${i}_neg.nii.gz >>${stdOut} 2>>${stdErr}
        overlay 0 0 ${preprocDir}/rrest.nii.gz -a rrest_CSF_PCA_${i}.nii.gz 100 1000 rrest_CSF_PCA_${i}_neg.nii.gz 100 1000 rrest_CSF_PCA_${i}_overlay >>${stdOut} 2>>${stdErr}
        fslroi rrest_CSF_PCA_${i}_overlay rrest_CSF_PCA_${i}_overlay_3d 0 1
        slicer rrest_CSF_PCA_${i}_overlay_3d -S 1 400 rrest_CSF_PCA_${i}_overlay.png >>${stdOut} 2>>${stdErr}
        rm -f rrest_CSF_PCA_${i}_neg.nii.gz
        fsl_tsplot -i rrest_CSF_PCA0${i}.1D -o rrest_CSF_PCA0${i}.png -w 2000 -h 144
    done
    cd ${preprocDir}
fi



if [ ! -e rrest_mc1o.par ]; then
    printStatus "Calculate Motion Regressors"
    # Calculate Regressors Using AFNI commands
    1d_tool.py -infile 'rrest.par[0..5]{0..'${nVols}'}' -write rrest_cut.par
    cat "${scriptDir}/zeros.par" rrest_cut.par > rrest_delayed.par
    1d_tool.py -infile 'rrest.par' -demean -overwrite -write rrest_demean.par
    1d_tool.py -infile 'rrest_delayed.par' -demean -overwrite -write rrest_delayed_demean.par
    1deval -a rrest.par[0] -expr 'a' > rrest_mc1o.par
    1deval -a rrest.par[1] -expr 'a' > rrest_mc2o.par
    1deval -a rrest.par[2] -expr 'a' > rrest_mc3o.par
    1deval -a rrest.par[3] -expr 'a' > rrest_mc4o.par
    1deval -a rrest.par[4] -expr 'a' > rrest_mc5o.par
    1deval -a rrest.par[5] -expr 'a' > rrest_mc6o.par
    1deval -a rrest_delayed.par[0] -expr 'a' > rrest_mc1d.par
    1deval -a rrest_delayed.par[1] -expr 'a' > rrest_mc2d.par
    1deval -a rrest_delayed.par[2] -expr 'a' > rrest_mc3d.par
    1deval -a rrest_delayed.par[3] -expr 'a' > rrest_mc4d.par
    1deval -a rrest_delayed.par[4] -expr 'a' > rrest_mc5d.par
    1deval -a rrest_delayed.par[5] -expr 'a' > rrest_mc6d.par
    1deval -a rrest_demean.par[0] -expr 'a*a' > rrest_mc1o2.par
    1deval -a rrest_demean.par[1] -expr 'a*a' > rrest_mc2o2.par
    1deval -a rrest_demean.par[2] -expr 'a*a' > rrest_mc3o2.par
    1deval -a rrest_demean.par[3] -expr 'a*a' > rrest_mc4o2.par
    1deval -a rrest_demean.par[4] -expr 'a*a' > rrest_mc5o2.par
    1deval -a rrest_demean.par[5] -expr 'a*a' > rrest_mc6o2.par
    1deval -a rrest_delayed_demean.par[0] -expr 'a*a' > rrest_mc1d2.par
    1deval -a rrest_delayed_demean.par[1] -expr 'a*a' > rrest_mc2d2.par
    1deval -a rrest_delayed_demean.par[2] -expr 'a*a' > rrest_mc3d2.par
    1deval -a rrest_delayed_demean.par[3] -expr 'a*a' > rrest_mc4d2.par
    1deval -a rrest_delayed_demean.par[4] -expr 'a*a' > rrest_mc5d2.par
    1deval -a rrest_delayed_demean.par[5] -expr 'a*a' > rrest_mc6d2.par
fi


designTypes=( Motion CompCor )
for designType in ${designTypes[@]}; do
    printStatus "Analyzing design: ${designType}"
    cp outliers.txt ${designType}Design

    cd ${designType}Design

    wait ${outlierID}
    if [ -e outliers.txt ]; then
        python3 "${scriptDir}/split_outliers.py" outliers.txt >>${stdOut} 2>>${stdErr}
    fi

    #
    # Create design file
    #=====================================================
    if [ ! -e ${designType}_design.fsf ]; then
        printStatus "Creating design file."
        echo `pwd`
        cp ${preprocDir}/${currentFunc} `pwd`
        cp ${preprocDir}/rrest_mc*.par `pwd`
        python3 "${scriptDir}/gen_${designType}_design_2023.py" `pwd`/${currentFunc} `pwd` >>${stdOut} 2>>${stdErr}
        /usr/local/fsl/bin/feat_model ${designType}_design
    #     rm -f rrest.nii.gz
    #     rm -f rrest_mc*.par
    fi


    #
    # Run GLM to remove noise
    #=====================================================
    if [ ! -e residuals_${designType}.nii.gz ]; then
        printStatus "Running GLM to remove noise"
        fsl_glm -i ${currentFunc} -d ${designType}_design.mat --out_res=residuals_${designType} -m ${preprocDir}/func_masked_mask.nii.gz >>${stdOut} 2>>${stdErr}
        fslmodhd residuals_${designType}.nii.gz pixdim4 ${tr} >>${stdOut} 2>>${stdErr}
        flirt -in ${T1Dir}/seg_seg_1.nii.gz -ref residuals_${designType}.nii.gz -out ${preprocDir}/seg_seg_1_inFuncSpace.nii.gz -interp nearestneighbour -applyxfm -init ${preprocDir}/highres2func.mat >>${stdOut} 2>>${stdErr}
        python3 "${scriptDir}/../../../../Utils/motionEffectImage.py" ${currentFunc} residuals_${designType}.nii.gz ${preprocDir}/seg_seg_1_inFuncSpace.nii.gz ${preprocDir}/rrest.par outliers.txt motionSummary_${designType} >>${stdOut} 2>>${stdErr}
        # rm -f ${preprocDir}/seg_seg_1_inFuncSpace.nii.gz
    fi


    #
    # Bandpass filter
    #=====================================================
#    if [ ! -e rd_rest_${designType}.nii.gz ]; then
#        printStatus "Spatial and temporal filtering"
#        #3dBandpass -band 0.01 0.1 -blur 6 -prefix rd_rest_mni -mask ${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask.nii.gz -input residuals.nii.gz
#        # High pass for task design, filter at 2 to 3 times task timing, e.g. task every 30 seconds -> 60 seconds -> 1/60=.016Hz
#        export DYLD_FALLBACK_LIBRARY_PATH=~/afni
#        3dBandpass -band 0.01 0.1 -blur 6 -prefix rd_rest_${designType} -mask ${preprocDir}/func_masked_mask.nii.gz -input residuals_${designType}.nii.gz >>${stdOut} 2>>${stdErr}
#        3dAFNItoNIFTI rd_rest_${designType}+orig.BRIK >>${stdOut} 2>>${stdErr}
#        gzip rd_rest_${designType}.nii
#        #https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;5b8cace9.0902
#        #fslmaths residuals.nii.gz -bptf 15 -1 -s 6 -mas func_masked_mask.nii.gz rd_rest.nii.gz
#    fi


    #
    # Normalize functional file
    #=====================================================
#    if [ ! -e rd_rest_${designType}_mni.nii.gz ]; then
#        printStatus "Normalizing functional file"
#        python3 "${scriptDir}/align4D.py" rd_rest_${designType}.nii.gz ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz ${preprocDir}/example_func2standard.mat rd_rest_${designType}_mni.nii.gz ${tr} >>${stdOut} 2>>${stdErr}
#    fi
#
#    if [ ! -e rd_rest_${designType}_mni.mp4 ]; then
#        #TODO Calculate a better threshold to use
#        "${scriptDir}/makeMovie.sh" rd_rest_${designType}_mni.nii.gz 5 50 ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz rd_rest_${designType}_mni >>${stdOut} 2>>${stdErr} &
#    fi
#
#    rm -f outlier*.txt

    cd ${preprocDir}
done

##
## ICA
##=====================================================
##echo "ICA"
##if [ ! -e rd_rest_mni.ica/melodic_IC.nii.gz ]
##then
##    melodic -i rd_rest_mni.nii.gz --nobet -m ${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask.nii.gz --bgimage=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --report
##fi
#
#echo "Generate HTML"
#if [ ! -e index.html ]
#then
#    python3 "${scriptDir}/gen_html.py" `pwd` 'RS'
#fi

#exit $?

#============================================================================================

#
# Create design file
#=====================================================
#echo "Creating design file."
#if [ ! -e RS_design.fsf ]; then
#    wait ${outlierID}
#    if [ -e outliers.txt ]; then
#        python3 "${scriptDir}/split_outliers.py" outliers.txt
#    fi
#    python3 "${scriptDir}/gen_RS_design.py" `pwd`/rrest_mni.nii.gz `pwd`/featDir
#fi
#
#
##
## Run GLM to remove noise
##=====================================================
#echo "Calculating residuals."
#if [ ! -e residuals.nii.gz ]; then
#    feat_model RS_design
#    fsl_glm -i rrest_mni.nii.gz -d RS_design.mat --out_res=residuals -m ${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask.nii.gz
#    # residuals come out with a 1 sec TR, change back to func's tr
#    fslmodhd residuals.nii.gz pixdim4 ${tr}
#    convert_xfm -omat example_highres2func.mat -inverse example_func2highres.mat
#    flirt -in ${T1Dir}/seg_seg_1.nii.gz -ref residuals.nii.gz -applyxfm -init example_highres2func.mat -out ${T1Dir}/seg_seg_1_inFuncSpace.nii.gz -interp nearestneighbour
#    #python3 "${scriptDir}/../../../../Utils/motionEffectImage.py" rrest.nii.gz residuals.nii.gz ${T1Dir}/seg_seg_1_inFuncSpace.nii.gz rrest.par outliers.txt motionSummary &
#    python3 "${scriptDir}/../../../../Utils/voxelVoxelCorrelationHist.py" rrest.nii.gz rrest_correlations &
#    python3 "${scriptDir}/../../../../Utils/voxelVoxelCorrelationHist.py" residuals.nii.gz residuals_correlations &
#fi
#
##
## Bandpass filter
##=====================================================
#echo "Temporal and spatial filtering."
#if [ ! -e rd_rest_mni.nii.gz ]; then
#    export DYLD_FALLBACK_LIBRARY_PATH=`dirname $(which afni)` #~/afni
#    3dBandpass -band 0.01 0.1 -blur 6 -prefix rd_rest_mni -mask ${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask.nii.gz -input residuals.nii.gz
#    ## High pass for task design, filter at 2*task timing, e.g. task every 30 seconds -> 60 seconds -> 1/60=.016Hz
#    #3dBandpass -band 0.01 99999 -blur 6 -prefix rd_rest_mni -mask ${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask.nii.gz -input residuals.nii.gz
#    3dAFNItoNIFTI rd_rest_mni+tlrc.BRIK
#    gzip rd_rest_mni.nii
#    #AFNI uses FWHM and FSL uses sigma for Gaussian spatial filter, FWHM = 2.3548*sigma
#    #fslmaths residuals.nii.gz -bptf 25 2.5 -s 3 -mas ${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask.nii.gz rd_rest_mni.nii.gz
#fi
#
#
