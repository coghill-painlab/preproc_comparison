#!/usr/bin/env bash


for subj_dir in $(ls -d /Volumes/Pain_lab_data/IDP/BOLD_Heat/IDP???)
do
        subj=$(basename $subj_dir)
        Echo $subj

#define input and output folders and input file (filtered_func_data). input file is the file preprocessed until before application of Melodic and FIX.
#It has undergone registration, mcflirt
        in_folder=$(ls -d /Volumes/Pain_lab_data/IDP/BOLD_Heat/low_level_bold_heat_melodic/test_data/${subj}/${subj}_bold_heat?_preprocessing_melodic_first_level)
        py_script_folder=/Volumes/Pain_lab_data/IDP/BOLD_Heat/fsf/shell_scripts

        for i in $in_folder
        do
                echo $i

                in_data=$(ls $i/filtered_func_data.nii.gz)

                echo $in_data

                if [[ $(basename $i | grep -ic "HEAT1") -eq 1 ]]; then
                        paradigm="heat1"
                        MR_paradigm="HEAT1"
                        echo "paradigm: " $paradigm
                elif [[ $(basename $i | grep -ic "HEAT2") -eq 1 ]]; then
                        paradigm="heat2"
                        MR_paradigm="HEAT2"
                        echo "paradigm: " $paradigm
                elif [[ $(basename $i | grep -ic "HEAT3") -eq 1 ]]; then
                        paradigm="heat3"
                        MR_paradigm="HEAT3"
                        echo "paradigm: " $paradigm
                else
                        echo "wrong paradigm number for " $subj
                fi

                #run tCompCor

                tCC_out_folder=/Volumes/Pain_lab_data/IDP/BOLD_Heat/${subj}/${subj}_bold_${paradigm}_tCC_preprocess
                echo $tCC_out_folder

                if [[ ! -d ${tCC_out_folder} ]]; then
                        mkdir -p $tCC_out_folder
                else
                        echo "output folder for tCC exists already"
                fi

                cd $tCC_out_folder


                python3 $py_script_folder/tCC_preprocess.py $in_data

                preprocDir=/Volumes/Pain_lab_data/IDP/derivative/${subj}/func/${subj}_*_${MR_paradigm}_*_CC

                echo "cleaning tcc data"
                fsl_glm -i $in_data -d ${tCC_out_folder}/tCompCor_components.txt --out_res=${tCC_out_folder}/residuals_${paradigm}_tCC -m ${preprocDir}/func_masked_mask.nii.gz

        done

done
