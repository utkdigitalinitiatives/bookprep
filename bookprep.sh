#!/usr/bin/env bash
printf "\n\n"
printf "%-6s | %-10s | %-10s\n" "Status" "Folder" "Description"
printf "%-6s | %-10s | %-10s\n" " ---- " " ---- " " ---- "

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
end=$'\e[0m'

# This script assumes your directory looks like the following tree view.
# ├── book/
# │   ├── bookprep.sh
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

for D in *; do
    if [ -d "${D}" ]; then

        # count how many unprocessed images are in the directory.
        tif_in_dir="$(ls -l ${D}/*.tif 2>/dev/null | wc -l)"
        jp2_in_dir="$(ls -l ${D}/*.jp2 2>/dev/null | wc -l)"

        # count how many processed images are in the directory.
        obj_tif_in_dir="$(ls -l ${D}/*/OBJ.tif 2>/dev/null | wc -l)"
        obj_jp2_in_dir="$(ls -l ${D}/*/OBJ.jp2 2>/dev/null | wc -l)"

        # sum the number of processed and unprocessed image separately.
        summed=$(( $tif_in_dir + $jp2_in_dir ))
        obj_summed=$(( $obj_tif_in_dir + $obj_jp2_in_dir ))

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
               # screen -d -m -S ${D} bash -c './bookprep.php '${D}' tif 2>&1 | tee --append ../output_log.txt'
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
            ARRAY[0]="$(ls -l ${D}/*/OCR.txt 2>/dev/null | wc -l)"
            ARRAY[1]="$(ls -l ${D}/*/MODS.xml 2>/dev/null | wc -l)"
            ARRAY[2]="$(ls -l ${D}/*/HOCR.html 2>/dev/null | wc -l)"
            issue=0

            # compare the number of processed images matches the number of OCR
            # files, the number of MODS files and the number of HOCR files.
            for i in "${ARRAY[@]}"
            do
                if [ "$i" -ne "$obj_summed" ] ; then
                    let issue=issue+1
                fi
            done

            # check to see if there are any derivatives file counts that don't match.
            if [ "$issue" != 0 ] ; then
                printf "%-12s | %-14s | %-30s\n" "    ${red}X${end} " "${red}${D}${end}" " PROBLEM: OCR=${ARRAY[0]} MODS=${ARRAY[1]} HOCR=${ARRAY[2]} OBJ=${obj_summed}"
                let all_done=all_done+1
            else
                # All files are equal and no unprocessed images.
                printf "%-12s | %-10s | %-10s\n" "    ${grn}+${end} " "${D}" "${grn}done${end}"
                # screen -X -S ${D} quit
            fi

        fi
        let COUNTER=COUNTER+1

      fi

done

printf "%-22s | %-10s\n" "# of incomplete" " ${grn}$all_done${end}"
#
# printf "Folder Size: $(du -sh)"
# printf "File types: $(find . -type f | sed 's/.*\.//' | sort | uniq -c)"

# echo mv "$(ls *.xml)"
# for filename in *.xml; do
#   mv ${filename} ${COUNTER}/${filename}
#   let COUNTER=COUNTER+1
# done
