#!/usr/bin/ksh

function ice2vilma {
        echo "                =================================================================="
        echo "                 *** S T A R T I N G    ice2vilma *** "; echo

        echo "                ICE_TO_VILMA=${ICE_TO_VILMA}"

        if [[ "x${ICE_TO_VILMA}" == "x1" ]]; then
                read_names ice solidearth
                iterative_coupling_ice_vilma_regrid
                iterative_coupling_ice_vilma_make_eislastfile
                iterative_coupling_ice_vilma_make_dflag
                iterative_coupling_ice_vilma_make_loadh
        else
                echo " NOT generating ice forcing for solid earth"
        fi
        echo
        echo "                 *** F I N I S H E D    ice2vilma *** "
        echo "                =================================================================="
}

function iterative_coupling_ice_vilma_regrid {

# Regrid to vilma input grid
        cdo -s \
                -remapcon,${VILMA_GRID_input} \
                -setgrid,${COUPLE_DIR}/ice.griddes \
                ${solidearth_ice_thickness_file} \
                ${COUPLE_DIR}/tmp.nc

# Split for ice thickness and mask
        ncks -v ${ice_thickness_name} ${COUPLE_DIR}/tmp.nc ${COUPLE_DIR}/tmp_${ice_thickness_name}.nc
        ncks -v ${ice_mask_name},${ice_topography_name} ${COUPLE_DIR}/tmp.nc ${COUPLE_DIR}/tmp_${ice_mask_name}.nc        

# Clean up
        rm ${COUPLE_DIR}/tmp.nc
}

function iterative_coupling_ice_vilma_make_eislastfile {

        ADD_UNCHANGED_ICE=${ADD_UNCHANGED_ICE:-0} # Options to add ice that is left unchanged by the ice sheet model results
        if [ "x${ADD_UNCHANGED_ICE}" == "x1" ]; then

                cdo -s \
                        setmisstoc,0 \
                        ${COUPLE_DIR}/tmp_${ice_thickness_name}.nc ${COUPLE_DIR}/tmp2_${ice_thickness_name}.nc

                cdo -s \
                        add ${COUPLE_DIR}/tmp2_${ice_thickness_name}.nc ${ADD_UNCHANGED_ICE_file} \
                        ${COUPLE_DIR}/eislastfile_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc

                rm tmp2_${ice_thickness_name}.nc
        else
                cdo -s \
                        setmisstoc,0 \
                        ${COUPLE_DIR}/tmp_${ice_thickness_name}.nc \
                        ${COUPLE_DIR}/eislastfile_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc  
        fi

# Make the file compatible with the format of the eislastfile
        ncap2 -s "time=time * 0.001" ${COUPLE_DIR}/eislastfile_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc -A ${COUPLE_DIR}/eislastfile_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
        ncrename -d time,epoch -v time,epoch ${COUPLE_DIR}/eislastfile_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
        ncatted -a units,epoch,o,c,'ka BP' ${COUPLE_DIR}/eislastfile_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
        ncatted -a long_name,epoch,o,c,'ka BP' ${COUPLE_DIR}/eislastfile_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
        ncrename -v ${ice_thickness_name},Ice ${COUPLE_DIR}/eislastfile_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc

        cp ${COUPLE_DIR}/eislastfile_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc ${EISLASTFILE_vilma}

# Clean up
        # In principle one can delete: rm ${COUPLE_DIR}/eislastfile_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
        rm tmp_${ice_thickness_name}.nc
}

function iterative_coupling_ice_vilma_make_dflag {

        if [[ ${RUN_NUMBER_vilma} > 1 ]]; then

# Select the relevant timesteps
                cdo -s \
                        delete,timestep=1 \
                        -delete,timestep=-1 \
                        ${COUPLE_DIR}/tmp_${ice_mask_name}.nc ${COUPLE_DIR}/tmp5.nc
                mv ${COUPLE_DIR}/tmp5.nc ${COUPLE_DIR}/tmp_${ice_mask_name}.nc
 
# Change from the ice sheet model mask to VILMA mask
                ncap2 -s "flg2=mask*0; where(mask==${VALUE_LAND_ice}){flg2=0;} where(mask==${VALUE_GROUNDED_ice}){flg2=2;} where((mask==${VALUE_GROUNDED_ice}) && (${ice_topography_name} < 0)){flg2=3;} where(mask==${VALUE_FLOATING_ice}){flg2=4;} where(mask==${VALUE_OCEAN_ice}){flg2=1;}" ${COUPLE_DIR}/tmp_${ice_mask_name}.nc ${COUPLE_DIR}/dflag-tmp_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc

# Import the existing dflag file that is to be changed
                cp ${DATA_DIR_vilma}/dflag.nc ${COUPLE_DIR}/to_merge.nc
                ncrename -d epoch,time -v epoch,time ${COUPLE_DIR}/to_merge.nc
                ncap2 -s "time=time * 1000." ${COUPLE_DIR}/to_merge.nc -A ${COUPLE_DIR}/to_merge.nc

# Merge to prepare for the replacement on the ice sheet model grid               
                cdo -s \
                        merge ${COUPLE_DIR}/dflag-tmp_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc ${COUPLE_DIR}/to_merge.nc \
                        ${COUPLE_DIR}/dflag-tmp2_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc

# Replace those areas affected by the ice sheet model
                ncap2 -s 'where (flg2 > -1) {flg=flg2;}' ${COUPLE_DIR}/dflag-tmp2_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc 

# Make the file compatible with the format of the dflag file
                ncap2 -s "time=double(time * 0.001)" ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc -A ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
                ncrename -d time,epoch -v time,epoch ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
                ncatted -a units,epoch,o,c,'ka BP' ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
                ncatted -a long_name,epoch,o,c,'Time Epoch' ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
                ncatted -a standard_name,epoch,o,c,'epoch' ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
                ncatted -a axis,epoch,o,c,'Epoch' ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
                ncatted -O -a calendar,epoch,d,, ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
                ncatted -O -a reference,flg,d,, ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
                ncks -v flg ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc ${COUPLE_DIR}/dflag_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc

                cp ${COUPLE_DIR}/dflag_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc ${DATA_DIR_vilma}/dflag.nc

# Clean up
                # In principle one can delete: rm ${COUPLE_DIR}/dflag_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
                rm ${COUPLE_DIR}/dflag-tmp_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
                rm ${COUPLE_DIR}/dflag-tmp2_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc
                rm ${COUPLE_DIR}/dflag-tmp3_vilma_${CURRENT_YEAR_ice}-${END_YEAR_ice}.nc       
        else
                continue
        fi

        rm tmp_${ice_mask_name}.nc         
}

function iterative_coupling_ice_vilma_make_loadh {

        if [ $RUN_NUMBER_ice -eq 1 ]; then

            : > ${COUPLE_DIR}/eislastconf_vilma.inp

            INITIAL_YEAR_vilma=$(echo "${INITIAL_DATE_vilma_standalone}" | awk '{print substr($0, 0, length($0)-6)}' )
            FINAL_YEAR_vilma=$(echo "${FINAL_DATE_vilma_standalone}" | awk '{print substr($0, 0, length($0)-6)}' )
            LOADH_NO_OF_RUNS=$(echo "((${FINAL_YEAR_vilma} - ${INITIAL_YEAR_vilma}) / ${NYEAR_vilma_standalone}) + 1" | bc )

            case ${VILMA_GRID_input} in
                "n128")
                    echo "256 512 910 1020" >> ${COUPLE_DIR}/eislastconf_vilma.inp
                    ;;
                "n256")
                    echo "512 1024 910 1020" >> ${COUPLE_DIR}/eislastconf_vilma.inp
                    ;;
                *)
                    echo "Undefined VILMA_GRID_input! Should be n128 or n256." >> ${COUPLE_DIR}/eislastconf_vilma.inp
            esac
            echo "${LOADH_NO_OF_RUNS}" >> ${COUPLE_DIR}/eislastconf_vilma.inp
            for i in $(seq ${INITIAL_YEAR_vilma} ${NYEAR_vilma_standalone} ${FINAL_YEAR_vilma})
            do
                LOADH_NEXT_VALUE=$(echo "${i} * 0.001" | bc -l ) 
                echo "${LOADH_NEXT_VALUE}" >> ${COUPLE_DIR}/eislastconf_vilma.inp
            done

            cp ${COUPLE_DIR}/eislastconf_vilma.inp ${EISLASTCONF_vilma}

        else
            continue
        fi

}



