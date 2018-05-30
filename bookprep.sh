#!/usr/bin/env bash


if [ "$1" == 'stop' ]; then
  clear
  printf "\n\t\tStopping all screen sessions by this user.\n\n\n"
  screen -ls | tail -n +2 | head -n -2 | awk '{print $1}'| xargs -I{} screen -S {} -X quit
  exit
fi

# Steps this app will take (steps with screen sessions will be noted with an "->" )
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# - initial                 - Looks for a config file
# - config-file-generated   - create working_directory and writes to .config file.
# - init_copies             -> copy the images/metadata into working_directory.
# - init_copies_complete    - checks if the image screen session is still running.
# - move_to_processing      - Move files to processing_101+
# - processing              -> Process the images with bookprep.php
# - processing-complete     - Processing images complete without errors.
# - cleanup-files-staging   -> move the files back to the expected parent structure.
# - moving-file-to-staging  -> Moving the files to stanging directory.
# - check-staging-move      - Check to see if staging move is complete.
# - complete                - print to screen message to inform user and exit.

LONGMESSAGE='
This script assumes your directory looks like the following tree view.

├── images/
│   ├── yrb_1897
│   │   ├── yrb_1897_001.jp2
│   │   └── yrb_1897_002.jp2
│   └── yrb_1898
│       ├── yrb_1898_001.jp2
│       └── yrb_1898_002.jp2
└── ...

├── metadata/
│   ├── yrb_1897.xml
│   ├── yrb_1898.xml
│   └── yrb_1899.xml
└── ...

├── staged/
│   ├── yrb_1897
│   │   ├── yrb_1897_001.jp2
│   │   └── yrb_1897_002.jp2
│   └──  yrb_1897.xml
│   ├── yrb_1898
│   │   ├── yrb_1898_001.jp2
│   │   └── yrb_1898_002.jp2
│   └──  yrb_1898.xml
└── ...
'

current_step="initial"
all_done=0
short_counter=101
missing_files=()
current_user="$(whoami)"
working_directory="/gwork/${current_user}/book_processing"
staging="/gwork/${current_user}/staging"
current_user_gwork="/gwork/${current_user}"
bookprep_location="$(pwd)/"
screen_session_names=(image_transfer metadata_transfer moving_to_staging processing_)
config_file="${working_directory}"/.config

# declare currently_running_init_rsync_sessions=0
ARRAY=()
how_many_directories=0

red=$'\e[1;31m'
bwn=$'\e[0;33m'
pur=$'\e[1;35m'
blu=$'\e[1;34m'
cyn=$'\e[1;36m'
dgr=$'\e[1;30m'
grn=$'\e[0;32m'
end=$'\e[0m'

# This is for debugging purposes only.
pause(){
  read -n1 -rsp $'press any\n'
  exit
}

# Does a screen session exist.
function find_screen {
  echo "$1"
    if screen -ls "$1" | grep -o "^\s*[0-9]*\.$1[ "$'\t'"](" --color=NEVER -m 1 | grep -oh "[0-9]*\.$1" --color=NEVER -m 1 -q >/dev/null; then
        screen -ls "$1" | grep -o "^\s*[0-9]*\.$1[ "$'\t'"](" --color=NEVER -m 1 | grep -oh "[0-9]*\.$1" --color=NEVER -m 1 2>/dev/null
        echo "$1"
        return 0
    else
        echo "$1"
        return 1
    fi
}

# Sends the exit command to screen sessions if idle
exit_screen_sessions(){
  screen -ls | tail -n +2 | head -n -2 | awk '{print $1}'| xargs -I{} screen -S {} -X stuff "exit^M"
}

# Writes directories and state to config_file. Line 3 must exist prior to this.
write_to_config(){
  current_step="$1"
  sed -i "3s/.*/current_step=\"${1}\"/" $config_file

  # Some OS need an extra empty string.
  # sed -i '' "3s/.*/current_step=\"${1}\"/" $config_file
}

# Recursive function to read in file locations
find_files(){
  # If variables have not been set, ask for them.
  if [ ! -d "${images_dir}" ] || [ ! -d "${metadata_dir}" ]; then
    echo "${LONGMESSAGE}"

    read -p "Where should this create the book_processing folder for processing (absolute path): " working_directory
    ! [[ "${working_directory:0:1}" == "/" ]] && clear echo "Must be an absolute path for the processing\n" && find_files

    read -p 'Where are the images (absolute path): ' images_dir
    ! [[ "${images_dir:0:1}" == "/" ]] && clear && find_files
    ! [ -d "${images_dir}" ] && clear && echo "image path doesn't exist\n" && find_files

    read -p 'Where is the metadata files (absolute path): ' metadata_dir
    ! [[ "${metadata_dir:0:1}" == "/" ]] && clear && find_files
    ! [ -d "${metadata_dir}" ] && clear && echo "metadata path doesn't exist\n" && find_files

    # Trailing char should be a /
    [ "${working_directory: -1}" == "/" ] && working_directory-='/'
    ! [ "${images_dir: -1}" == "/" ] && images_dir+='/'
    ! [ "${metadata_dir: -1}" == "/" ] && metadata_dir+='/'

    # user_input_valid
    ! [ -d "${working_directory}" ] && mkdir "${working_directory}"

    # Looking for an empty config file.
    cd "${working_directory}"
    find . -type f -empty -delete

    # Creating an empty config file.
    echo -n '' > $config_file
    echo images_dir="${images_dir}" >> $config_file
    echo metadata_dir="${metadata_dir}" >> $config_file
    echo current_step=config-file-generated >> $config_file
  fi
}

# checks if already processing and initiates the merging of the images and metadata.
init_copies(){
  # Folder name start with 101. Screen sessions have restrictions on naming
  # and counting is easier to keep track when the leading char is the same.
  # printf '\nchecking if the files exist and are processing or already staged\n\n'
  cd "/gwork/${current_user}"

  # If book_processing doesn't exist, make it.
  [ -d book_processing ] || mkdir book_processing

  cd "${working_directory}"

  # Once started these folders should exist.
  if [ ! -d "${working_directory}/processing_101" ] && [ ! -d "${staging}" ]; then
    # This does introduce a race condition but typically the image folder will always take longer.
      if ! screen -list | grep -q "image_transfer"; then

        screen -d -m -S metadata_transfer
        screen -S metadata_transfer -p 0 -X exec rsync --progress -azv --exclude=.DS_Store --exclude=._* "${metadata_dir}" "${working_directory}"

        screen -d -m -S image_transfer
        screen -S image_transfer -p 0 -X exec rsync --progress -azv --exclude=.DS_Store --exclude=._* "${images_dir}" "${working_directory}"

        # Change state
        write_to_config "init_copies"
    fi
  fi
}

init_copies_complete_check(){

  printf "\n\t${blu}Checking if initial transfer to ${working_directory} is complete${end}\n"
  if ! find_screen "metadata_transfer" > /dev/null ; then

    printf "\n\t${grn}Metadata transfer complete${end}\n"
    if ! find_screen "image_transfer" > /dev/null ; then

      # Change state
      write_to_config "move_to_processing"
      printf "\t${grn}Image transfer complete${end}\n"
    else
      printf "\t${cyn}Image transfer still going${end}\n"
    fi

  else
    printf "\n\t${cyn}Metadata transfer still going${end}\n"
  fi

  # exit_screen_sessions
  printf "\n"
  printf "\t%-6s : %-10s\n" "Image/Metadata Files" "${red}$(find ${images_dir} | wc -l)${end}"
  printf "\t%-6s : %-10s\n\n\n" "Copied" "${pur}$(find ${working_directory} | wc -l)${end}"
}

# main process to check if already being processed and detirmine the status.
processing(){
    cd $working_directory
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

    declare currently_running_sessions=0

    for D in *; do
        if [ -d "${D}" ]; then
            # count how many screen sessions are running
            let currently_running_sessions="$(ls /dev/pts/ 2>/dev/null | wc -l)"

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
    		               if ! find_screen ${D} >/dev/null; then
                       max_sessions=$[$currently_running_sessions - 100]
                         if [ "$max_sessions" -lt 0 ]; then
                           DIRARRAY+=("${D}")
                           screen -d -m -S ${D}
                           screen -S ${D} -p 0 -X exec ${bookprep_location}bookprep.php ${D} 'jp2'
                         fi
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


    tLen=${#missing_files[@]}
    cd "${working_directory}"
    let how_many_directories="$(ls | wc -l)"
    if [ $all_done -eq 0 ] && [ ! -d ${staging} ]; then
      value="processing_"
      if [ ${tLen} = 0 ] && [ ${how_many_directories} -gt 0 ]; then
        write_to_config "processing-complete"
      fi
    fi
}

move_to_processing(){
  if [ -d "${working_directory}" ] && [ ! -d "${working_directory}/processing_101" ]; then

      cd "${working_directory}"
      printf 'Files transferred.\n\n\tRenaming files with "-" to "_" (test-01.tif to test_01.tif)\n'
      rename "s/-/_/g" *

      for E in *; do
          if [ -d "${E}" ]; then
            mkdir "processing_${short_counter}"
            mv "${E}" "processing_${short_counter}/"
            mv "${E}.xml" "processing_${short_counter}/"
            let short_counter=short_counter+1
          fi
      done
      write_to_config "processing"
  fi
}

moving-file-to-staging(){
  cd $working_directory
  printf "Moving to ${staging} folder\n"
  if [ ! -d ${staging} ]; then
    printf "Initializing the file move to ${staging}. Initializing rsync session\n\n"
    screen -d -m -S moving_to_staging
    screen -S moving_to_staging -p 0 -X stuff "rsync -avz --remove-source-files processing_*/* $staging ^M exit^M"
  fi
  write_to_config "check-staging-move"
}

check-staging-move(){
  exit_screen_sessions
  if [ -d ${staging} ]; then
    if ! find_screen "moving_to_staging" > /dev/null ; then
      write_to_config "complete"
    fi
  else
    if ! find_screen "moving_to_staging" > /dev/null ; then
      write_to_config "moving-file-to-staging"
    fi
  fi
}

# If it won't start check to make sure there aren't odd files.
# printf "File types: $(find . -type f | sed 's/.*\.//' | sort | uniq -c)"

while true; do
  # reads the config file
  clear
  printf "\n\n"
  echo -e "${pur}################################################################################${end}"
  echo -e "\tThis script will exit ${red}ALL${end} idle screens sessions by this user."
  echo -e "${pur}################################################################################${end}"
  printf "\n\n"

  if [ -f $config_file ];then
    . $config_file
  fi

case $current_step in
    initial)
      echo -e "\n\tCurrently on step #1: initial"
      (find_files)
      ;;
    config-file-generated)
      echo -e "\n\tCurrently on step #2: config-file-generated"
      (init_copies)
      ;;
    init_copies)
      echo -e "\n\tCurrently on step #3: init_copies"
      (init_copies_complete_check)
      ;;
    init_copies_complete_check)
      echo -e "\n\tCurrently on step #4: init_copies_complete_check"
      (init_copies_complete_check)
      ;;
    move_to_processing)
      echo -e "\n\tCurrently on step #5: move_to_processing"
      (move_to_processing)
      ;;
    processing)
      echo -e "\n\tCurrently on step #6: processing"
      (processing)
      ;;
    processing-complete)
      echo -e "\n\tCurrently on step #7: processing-complete"
      (moving-file-to-staging)
      ;;
    moving-file-to-staging)
      echo -e "\n\tCurrently on step #7: processing-complete"
      (moving-file-to-staging)
      ;;
    check-staging-move)
      echo -e "\n\tCurrently on step #8: check-staging-move"
      (check-staging-move)
      ;;
    complete)
      clear
      printf "\n\n\n\t\t\tDONE!\n\n\tFiles have been moved to ${staging} and are ready for ingest.\n\n\n\n"
      rm -rf $working_directory
      exit
      ;;
      *)
      echo "Didn't find state\n"
      echo $current_step
      ;;
esac

    printf '\nYou can close this and reopen it at any time. This script will complete this step and will wait to start the next one.\n\n'
    printf 'Waiting 30 seconds to allow screen sesions to initialize. \n'
  	echo -n -e "Waiting 30 seconds to allow screen sesions to initialize.\n" >> ../report.txt
    printf "You can ${bwn}ctrl c${end} at anytime. It will not stop the background sessions\n"
  	echo -n -e "You can ctrl c at anytime. It will not stop the background sessions \n\n\n" >> ../report.txt

    secs=$((30))
    while [ $secs -gt 0 ]; do
       echo -ne " ${pur}$secs${end}\033[0K\r"
       sleep 1
       : $((secs--))
    done
    exit_screen_sessions
done

# if something fails use this command to clear ALL of your sessions.
# screen -ls | tail -n +2 | head -n -2 | awk '{print $1}'| xargs -I{} screen -S {} -X quit
