#!/usr/bin/env bash


for subj_dir in $(ls -d /Volumes/Pain_lab_data/IDP/BOLD_Heat/IDP???)
do
        subj=$(basename $subj_dir)
        Echo $subj

#define input and output folders and input file (filtered_func_data). input file is the file preprocessed until before application of Melodic and FIX.

        in_folder=$(ls -d ${subj_dir}/${subj}_bold_heat?_48_block_design_noIntensityNormalization_first_level.feat)
        py_script_folder=/Volumes/Pain_lab_data/IDP/BOLD_Heat/fsf/ICA_AROMA/ICA-AROMA

        for i in $in_folder
        do
                echo $i

                out_dir=${i}/ICA_AROMA_test


                echo $out_dir

                #run ica AROMA

                python3 ${py_script_folder}/ICA_AROMA.py -feat $i -den both -out $out_dir -overwrite



        done


        #$in_data



done
