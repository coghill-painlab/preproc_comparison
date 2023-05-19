#!/usr/bin/env bash

cd /Volumes/Pain_lab_data/IDP
#subj_list=$(ls -d /Volumes/Pain_lab_data/IDP/derivative/IDP??? ls -d /Volumes/Pain_lab_data/Individual_differences/derivative/IDP???) # $(ls -d /Volumes/Pain_lab_data/IDP/derivative/IDP001)
subj_list=$(ls -d /Volumes/Pain_lab_data/Individual_differences/derivative/IDP054) # $(ls -d /Volumes/Pain_lab_data/IDP/derivative/IDP001)
printStatus() {
    printf "\t${1}\n"
}

 # mkdir -p /Volumes/Pain_lab_data/IDP/bold_heat_melodic/training_data
 # mkdir /Volumes/Pain_lab_data/IDP/bold_heat_melodic/test_data

for subj_dir in ${subj_list[@]} #/Volumes/Pain_lab_data/IDP/derivative/IDP???
do
    echo $subj_dir
    subj=$(basename $subj_dir)
    echo $subj

    #list all bold heat scans
    raw_data=$(ls -d $subj_dir/func/*BOLD*HEAT1*.nii.gz)

    #check that there is at least 2 bold heat scans, otherwise won't run. If not 3 scans: warning in txt file
    # if [[ $(echo $raw_data | wc -w) -ge 2 ]]; then
    #     if [[ $(echo $raw_data | wc -w) -ne 3 ]]; then
    #         echo "missing bold heat scan for st " $subj >> /Volumes/Pain_lab_data/IDP/BOLD_Heat/incomplete_analyses/missing_data_melodic_preprocess_first_level_`date +"%d-%m-%Y"`.txt
    #     fi

        #run for all available bold heat scans
        # for i in $raw_data
        # do
        i=$raw_data
            echo $i
            printStatus "prepping dataset"
            rawdat=$i

            #define which heat run is being processed
            if [[ $(basename $i | grep -ic "HEAT1") -eq 1 ]]; then
            paradigm="heat1"
            IDparadigm="Heat_1"
            echo $paradigm
            elif [[ $(basename $i | grep -ic "HEAT2") -eq 1 ]]; then
            paradigm="heat2"
            IDparadigm="Heat_2"
            echo $paradigm
            elif [[ $(basename $i | grep -ic "HEAT3") -eq 1 ]]; then
            paradigm="heat3"
            IDparadigm="Heat_3"
            echo $paradigm
            else
            echo "wrong paradigm number for " $subj
            fi

            if [[ $(echo $i | awk -F / '{ print $4 }' | grep -ic "IDP") -eq 1 ]]; then
              outputDir=/Volumes/Pain_lab_data/IDP/bold_heat_melodic/test_data/${subj}/${subj}_bold_${paradigm}_preprocessing_melodic_first_level
              inputdir=/Volumes/Pain_lab_data/IDP/derivative/${subj}
              mdldir=/Volumes/Pain_lab_data/IDP/BOLD_Heat/$subj/${subj}_${paradigm}_48_block_design_newPrestats.feat
              echo $outputDir
              echo $inputdir
              echo $mdldir
            else
              outputDir=/Volumes/Pain_lab_data/IDP/bold_heat_melodic/training_data/${subj}/${subj}_bold_${paradigm}_preprocessing_melodic_first_level
              inputdir=/Volumes/Pain_lab_data/Individual_differences/derivative/${subj}
              mdldir=/Volumes/Pain_lab_data/Individual_differences/derivative/${subj}/beh_imaging/glm_model_block_design_48/${IDparadigm}
              echo $outputDir
              echo $inputdir
              echo $mdldir
            fi

            if [[ ! -d $outputDir ]]; then
              mkdir -p $outputDir

            echo ${outputDir}
            cd ${outputDir}

            fslmaths ${i} prefiltered_func_data -odt float

            fslroi prefiltered_func_data example_func 96 1


# #########################################################################################################################################################################
#           #registration
# #########################################################################################################################################################################
#
            printStatus "registration in process"

#create output folder for registration
            if [[ ! -d ${outputDir}/reg ]]; then
              mkdir -p ${outputDir}/reg
            fi

            #check T1 is betted already. If not, call T1_process script
            #T1dir=$(ls -d /Volumes/Pain_lab_data/IDP/derivative/${subj}/func/T1Proc)
            T1dir=${inputdir}/func/T1Proc

#if brain has noot been segmented and betted, do so now
            if [ ! -d ${T1dir} ]; then
                  printStatus "starting T1 processing script"
                  mkdir ${T1dir}
                  scriptDir=/usr/local/bin/cchmc_MRI_scripts/ProcessingScripts_TCM/
                  echo $scriptDir
                  #inT1=`/Volumes/Pain_lab_data/IDP/derivative/${subj}/anat/o*avg*.nii.gz`
                  inT1=${inputdir}/anat/o*avg*.nii.gz
                  echo $inT1
                  ${scriptDir}/T1_process.sh ${inT1} ${T1dir} ${scriptDir} T1Proc_ID=${!}
            fi
#           # echo $(ls ${outputDir})
           # pwd
            cp example_func.nii.gz reg/

# prep/rename structural files

            fslmaths ${T1dir}/anat_brain.nii.gz ./reg/T1brain
            fslmaths ${T1dir}/anat.nii.gz ./reg/T1head
            fslmaths ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz ./reg/standard
            fslmaths ${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz ./reg/standard_head
            fslmaths ${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask_dil.nii.gz ./reg/standard_mask

            #register func to highres/anat
            cd ${outputDir}/reg/

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

            cd ${outputDir}
# #
# #########################################################################################################################################################################
#           #preprocessing
# #########################################################################################################################################################################
#
#mcflirt
            printStatus "motion correction in process"

            if [[ ! -d ${outputDir}/mc ]]; then
                mkdir -p ${outputDir}/mc
            fi
#            mkdir -p ${ouptutDir}/mc
            cp prefiltered_func_data.nii.gz mc/
            cp example_func.nii.gz mc/
            cd mc

            mcflirt -in prefiltered_func_data -out prefiltered_func_data_mcf -mats -plots -reffile example_func -rmsrel -rmsabs -spline_final
            fsl_tsplot -i prefiltered_func_data_mcf.par -t 'MCFLIRT estimated rotations (radians)' -u 1 --start=1 --finish=3 -a x,y,z -w 640 -h 144 -o rot.png
            fsl_tsplot -i prefiltered_func_data_mcf.par -t 'MCFLIRT estimated translations (mm)' -u 1 --start=4 --finish=6 -a x,y,z -w 640 -h 144 -o trans.png
            fsl_tsplot -i prefiltered_func_data_mcf_abs.rms,prefiltered_func_data_mcf_rel.rms -t 'MCFLIRT estimated mean displacement (mm)' -u 1 -w 640 -h 144 -a absolute,relative -o disp.png
            cd ${outputDir}

#slice timing correction
            printStatus "slice timing correction in process"
            if [[ ! -d ${outputDir}/preproc ]]; then
                mkdir -p ${outputDir}/preproc
            fi

            cp mc/prefiltered_func_data_mcf.nii.gz preproc/

            cd preproc
            slicetimer -i prefiltered_func_data_mcf --out=prefiltered_func_data_st -r 2.000000
            fslmaths prefiltered_func_data_st -Tmean mean_func

#bet func
            printStatus "betting and creating mask for func"
            bet2 mean_func mask -f 0.3 -n -m; immv mask_mask mask
            fslmaths prefiltered_func_data_st -mas mask prefiltered_func_data_bet
            thresh=$( fslstats prefiltered_func_data_bet -p 98 )
            echo ${thresh}
            thresh10=$(echo "$thresh / 10" | bc -l)
            fslmaths prefiltered_func_data_bet -thr ${thresh10}  -Tmin -bin mask -odt char
            med_perc=$(fslstats prefiltered_func_data_st -k mask -p 50)
            echo ${med_perc}
            perc2=$(fslstats prefiltered_func_data_st -k mask -p 2)
            echo ${perc2}
            bt_thresh=$(echo "($med_perc - $perc2) * 0.75" | bc -l)
            fslmaths mask -dilF mask
            fslmaths prefiltered_func_data_st -mas mask prefiltered_func_data_thresh
            fslmaths prefiltered_func_data_thresh -Tmean mean_func

#spatial smoothing
            printStatus "spatial smoothing in process"
            susan prefiltered_func_data_thresh ${bt_thresh} 2.12314225053 3 1 1 mean_func ${bt_thresh} prefiltered_func_data_smooth
            fslmaths prefiltered_func_data_smooth -mas mask prefiltered_func_data_smooth
            normmean=10000
            scaling=$(echo "$normmean / $med_perc" | bc -l)
            fslmaths prefiltered_func_data_smooth -mul $scaling prefiltered_func_data_intnorm
            fslmaths prefiltered_func_data_intnorm -Tmean tempMean

#high pass filtering
            printStatus "high pass filtering with cutoff at 100s"
            fslmaths prefiltered_func_data_intnorm -bptf 25.0 -1 -add tempMean prefiltered_func_data_tempfilt
            imrm tempMean
            fslmaths prefiltered_func_data_tempfilt ../filtered_func_data
            cd ${outputDir}
            fslmaths filtered_func_data -Tmean mean_func

            printStatus "preprocessing completed"

#########################################################################################################################################################################
          #melodic
#########################################################################################################################################################################
cd ${outputDir}
                #define directory where to find the models for post-stats analysis
                printStatus "starting melodic"

                #model_dir=/Volumes/Pain_lab_data/IDP/BOLD_Heat/$subj/${subj}_${paradigm}_48_block_design_newPrestats.feat
                model_dir=${mdldir}

                model_mat=${model_dir}/design.mat
                model_con=${model_dir}/design.con

                output_25comp=${outputDir}/${subj}_${paradigm}_melodic_25comp.ica

                echo $output_25comp

                printStatus "running melodic with 25 components"
                melodic -i filtered_func_data -o ${output_25comp} -v --nobet --bgthreshold=3 --tr=2 --report -d 25 --mmthresh=0.5 --Tdes=${model_mat} --Tcon=${model_con}

                printStatus "melodic completed for ${subj}, run ${paradigm}"
                echo "subject ${subj} heat run ${paradigm} completed" >> /Volumes/Pain_lab_data/IDP/BOLD_Heat/completed_analyses/analysis_completed_melodic_preprocess_first_level_`date +"%d-%m-%Y"`.txt
              # else printStatus "subject ${subj} heat run ${paradigm} already completed "
              # fi
        # done

  #  fi


done
