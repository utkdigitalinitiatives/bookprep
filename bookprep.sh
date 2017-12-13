#!/usr/bin/env bash
printf "\n\n"
printf "%-6s | %-10s | %-10s\n" "Status" "Folder" "Description"
printf "%-6s | %-10s | %-10s\n" " ---- " " ---- " " ---- "

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
cyn=$'\e[1;36m'
end=$'\e[0m'

# This script assumes your directory looks like the following tree view.
# bookprep.sh
# ├── book/
# │   ├── yrb_1897
# │   │   ├── yrb_1897_001.jp2
# │   │   └── yrb_1897_002.jp2
# │   └──  yrb_1897.xml
# │   ├── yrb_1898
# │   │   ├── yrb_1898_001.jp2
# │   │   └── yrb_1898_002.jp2
# │   └──  yrb_1898.xml
# └── ...
all_done=0
missing_files=()

short_counter=101
if [ ! -d ./processing_101 ] && [ ! -d ../staged ]
then
    for E in *; do
        if [ -d "${E}" ]; then
          mkdir "processing_${short_counter}"
          mv "${E}" "processing_${short_counter}/"
          mv "${E}.xml" "processing_${short_counter}/"
          let short_counter=short_counter+1
        fi
    done
fi


for D in *; do
    if [ -d "${D}" ]; then

        # count how many unprocessed images are in the directory.
        tif_in_dir="$(ls -l ${D}/*/*.tif 2>/dev/null | wc -l)"
        jp2_in_dir="$(ls -l ${D}/*/*.jp2 2>/dev/null | wc -l)"

        # count how many processed images are in the directory.
        obj_tif_in_dir="$(ls -l ${D}/*/*/OBJ.tif 2>/dev/null | wc -l)"
        obj_jp2_in_dir="$(ls -l ${D}/*/*/OBJ.jp2 2>/dev/null | wc -l)"

        # sum the number of processed and unprocessed image separately.
        summed=$(( $tif_in_dir + $jp2_in_dir ))
        obj_summed=$(( $obj_tif_in_dir + $obj_jp2_in_dir ))
        TYPE_IMG='jp2'
        if [ $tif_in_dir != 0 ]; then
          let TYPE_IMG='tif'
        fi
        # if there are unproccessed images in the directory
        if [ $tif_in_dir != 0 ] || [ $jp2_in_dir != 0 ]; then
           # if there is also processed images in the directory.
           if [ $summed != 0 ] && [ $obj_summed != 0 ]; then
             printf "%-12s | %-10s | %-10s\n" "    ${yel}*${end} " "${D}" " ${yel}processing...${end}"
           else
             # no images processed yet in this directory.
             # Check to see if there is a session already running by that name.
             if ! screen -list | grep -q ${D}; then
               echo screen -list | grep -q ${D}
               screen -d -m -S ${D}
               screen -S ${D} -p 0 -X exec ./bookprep.php ${D} ${TYPE_IMG}
             fi
             printf "%-12s | %-10s | %-10s\n" "    ${blu}_${end} " "${D}" " ${blu}pending${end} "
           fi
           let all_done=all_done+1
        fi

        # check that the directory has no unprocessed images and has
        # at minimal one processed image.
        if [ $summed == 0 ] && [ $obj_summed != 0 ]; then
            ARRAY=()

            # Count the number of derivatives generated for OCR, MODS, and HOCR.
            ARRAY[0]="$(ls -l ${D}/*/*/OCR.txt 2>/dev/null | wc -l)"
            ARRAY[1]="$(ls -l ${D}/*/*/MODS.xml 2>/dev/null | wc -l)"
            ARRAY[2]="$(ls -l ${D}/*/*/HOCR.html 2>/dev/null | wc -l)"
            issue=0
            # compare the number of processed images matches the number of OCR
            # files, the number of MODS files and the number of HOCR files.
            for i in "${ARRAY[@]}"
            do
                if [ "$i" -ne "$obj_summed" ] ; then
                    missing_files+=("$(find ${D} -mindepth 3 -maxdepth 3 -type d '!' -exec test -e '{}/OCR.txt' ';' -print)")
                    missing_files+=("$(find ${D} -mindepth 3 -maxdepth 3 -type d '!' -exec test -e '{}/MODS.html' ';' -print)")
                    missing_files+=("$(find ${D} -mindepth 3 -maxdepth 3 -type d '!' -exec test -e '{}/HOCR.html' ';' -print)")
                    let issue=issue+1
                fi
            done

            # check to see if there are any derivatives file counts that don't match.
            if [ "$issue" != 0 ] ; then
                printf "%-12s | %-10s | %-30s\n" "    ${cyn}X${end} " "${D}" "MISSING OCR, HOCR"
                let all_done=all_done+1
                if [ "${ARRAY[1]}" -ne "$obj_summed" ]; then
                    printf "%-12s | %-10s | %-30s\n" "    ${red}X${end} " "${D}" " PROBLEM: with MODS"
                fi
            else
                # All files are equal and no unprocessed images.
                printf "%-12s | %-10s | %-10s\n" "    ${grn}+${end} " "${D}" "${grn}done${end}"
                #screen -X -S ${D} quit
            fi

        fi
        let COUNTER=COUNTER+1

      fi

done

printf "%-22s | %-10s\n" "# of incomplete" " ${grn}$all_done${end}"
printf 'Files that are missing\n'
printf '%s ' "${missing_files[@]}"
printf '\n'
printf "Folder Size: $(du -sh) \n"


if [  $all_done -eq 0 ] && [ ! -d ../staged ]; then
  # mkdir ../staged
  for F in *; do
        if [ -d "${F}" ]; then
          rsync --progress --remove-source-files -azv "${F}/" "../staged"
        fi
    done
  rm -rf */
fi


# Delay the script from exiting to prevent overlapping sessions.
# Looks for a processed image to indicate the screen session is started
printf 'Checking..... \n'

if [ $all_done -gt 0 ]; then
  sleep 30
fi
