#!/usr/bin/env bash

all_done=0
missing_files=()

red=$'\e[1;31m'
bwn=$'\e[0;33m'
pur=$'\e[1;35m'
blu=$'\e[1;34m'
cyn=$'\e[1;36m'
dgr=$'\e[1;30m'
end=$'\e[0m'


# Black            \e[0;30m
# Blue             \e[0;34m
# Green            \e[0;32m
# Cyan             \e[0;36m
# Red              \e[0;31m
# Purple           \e[0;35m
# Brown            \e[0;33m
# Gray             \e[0;37m
# Dark Gray        \e[1;30m
# Light Blue       \e[1;34m
# Light Green      \e[1;32m
# Light Cyan       \e[1;36m
# Light Red        \e[1;31m
# Light Purple     \e[1;35m
# Yellow           \e[1;33m
# White            \e[1;37m


# checks and preps for processing.
main_prep() {
  # Folder name start with 101. Screen sessions have restrictions on naming
  # and counting is easier to keep track when the leading char is the same.
  short_counter=101
  # checks if files are processing or already staged
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
}

# main process to check if already being processed and detirmine the status.
main_start() {
    if ls ../report.txt 1> /dev/null 2>&1; then
      echo "$(date)" > ../report.txt
    else
      touch ../report.txt
    fi

    let all_done=0
    missing_files=()

    printf "\n\n${red}Bookprep Helper 2.0${end}\n\n"
		echo -n -e "Bookprep Helper 2.0\n" >> ../report.txt
    printf "%-6s | %-14s | %-10s\n" "Status" "Folder" "Description"
		echo -n -e "Status | Folder | Description\n" >> ../report.txt
    printf "%-6s | %-14s | %-10s\n" " ---- " " ---- " " ---- "
		echo -n -e " ----   ----   ---- \n" >> ../report.txt

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
            how_many_left=$(( $summed ))

            # if there are unproccessed images in the directory
            if [ $tif_in_dir != 0 ] || [ $jp2_in_dir != 0 ]; then
               # if there is also processed images in the directory.
               if [ $summed != 0 ] && [ $obj_summed != 0 ]; then
                 printf "%-12s | %-14s | %-10s\n" "    ${pur}*${end} " "${D}" " ${pur}processing... ${how_many_left}${end}"
								 echo -n -e "${D} processing... ${how_many_left}\n" >> ../report.txt
               else

                 # no images processed yet in this directory.
                 # Check to see if there is a session already running by that name.
                 if ! screen -list | grep -q ${D}; then
                   echo screen -list | grep -q ${D}
                   screen -d -m -S ${D}

		   # Checks to mach input to output but comenting out for now to save space
                   #if [ $tif_in_dir != 0 ]; then
                   #   screen -S ${D} -p 0 -X exec ./bookprep.php ${D} 'tif'
                   #fi
                   #if [ $jp2_in_dir != 0 ]; then
                   #   screen -S ${D} -p 0 -X exec ./bookprep.php ${D} 'jp2'
                   #fi
		   screen -S ${D} -p 0 -X exec ./bookprep.php ${D} 'jp2'

                 fi
                 printf "%-12s | %-14s | %-10s\n" "    ${blu}_${end} " "${D}" " ${blu}pending${end} "
								 echo -n -e "_ ${D} pending \n" >> ../report.txt
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
                    printf "%-12s | %-14s | %-30s\n" "    ${cyn}X${end} " "${D}" "MISSING OCR, HOCR"
										echo -n -e "X ${D} MISSING OCR, HOCR\n" >> ../report.txt
                    let all_done=all_done+1
                    if [ "${ARRAY[1]}" -ne "$obj_summed" ]; then
                        printf "%-12s | %-14s | %-30s\n" "    ${red}X${end} " "${D}" " PROBLEM: with MODS"
												echo -n -e "X ${D} PROBLEM: with MODS\n" >> ../report.txt
                    fi
                else
                    # All files are equal and no unprocessed images.
                    printf "%-12s | %-14s | %-10s\n" "    ${bwn}+${end} " "${D}" " ${dgr}- - done - -${end}"
										echo -n -e "+ ${D} - - done - -\n" >> ../report.txt
                fi
            fi
            let COUNTER=COUNTER+1
          fi
    done

    printf "  ${cyn}-----------------------------------------${end}\n"
		echo -n -e "  ----------------------------------------- \n" >> ../report.txt
    printf "%-23s | %-10s\n" "# of incomplete" " ${red}$all_done${end}"
		echo -n -e "# of incomplete ${all_done}\n" >> ../report.txt
    printf "%-23s | %-10s\n\n" "Files that are missing" "${missing_files[@]}"
		echo -n -e "Files that are missing ${missing_files[@]}\n" >> ../report.txt
    printf "Estimated folder size: ${blu}$(du -sh)${end} \n\n"
		echo -n -e "Estimated folder size: $(du -sh)\n" >> ../report.txt
    if [ $all_done -eq 0 ] && [ ! -d ../staged ]; then
      exit 255
    fi
}

# If it won't start check to make sure there aren't odd files.
# printf "File types: $(find . -type f | sed 's/.*\.//' | sort | uniq -c)"

while true; do
  clear
  (main_prep)
  (main_start)
  res=$?
  if (( res == 255 )); then
    mkdir ../staged
    for F in *; do
          if [ -d "${F}" ]; then
            rsync --progress --remove-source-files -azv "${F}/" "../staged"
          fi
      done
    rm -rf */
    break
  fi

  printf 'Waiting 30 seconds to allow screen sesions to initialize. \n'
	echo -n -e "Waiting 30 seconds to allow screen sesions to initialize.\n" >> ../report.txt
  printf "You can ${bwn}ctrl c${end} at anytime. It will not stop the background sessions\n\n"
	echo -n -e "You can ctrl c at anytime. It will not stop the background sessions\n\n\n" >> ../report.txt
  secs=$((30))
  while [ $secs -gt 0 ]; do
     echo -ne " ${pur}$secs${end}\033[0K\r"
     sleep 1
     : $((secs--))
  done
done

# if something fails use this command to clear ALL of your sessions.
# screen -ls | tail -n +2 | head -n -2 | awk '{print $1}'| xargs -I{} screen -S {} -X quit
# Or just one secreen session
#screen -X -S ${D} quit
