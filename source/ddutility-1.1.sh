#!/bin/bash
#
# dd Utility version 1.1 - Linux/Ubuntu 
#
# Write and Backup Operating System IMG files on Memory Card 
#
# By The Fan Club 2015
# http://www.thefanclub.co.za
#
### BEGIN LICENSE
# Copyright (c) 2015, The Fan Club <info@thefanclub.co.za>
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranties of
# MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.
### END LICENSE
#
### NOTES 
#
# Dependencies : zenity pv zip xz gzip dd
#
# To run script make executable with: sudo chmod +x ddutility.sh
# and then run with: sudo ddutility.sh
#
###

# Vars
apptitle="dd Utility"
version="1.1 beta"
export LC_ALL=en_US.UTF-8
mountpath="/media/$SUDO_USER"

# Set Icon directory and file 
iconfile="notification-device"

# Read args
if [ "$1" == "--Backup" ] ; then
  action="Backup"
fi
if [ "$1" == "--Restore" ] ; then
  action="Restore"
fi

# Filesize conversion function
function filesizehuman () {
  filesize=$1
  if [ "$filesize" -gt 1000000000000 ] ; then
    fsize="$( echo "scale=2; $filesize/1000000000000" | bc ) TB" 
  elif [ "$filesize" -gt 1000000000 ] ; then
    fsize="$( echo "scale=2; $filesize/1000000000" | bc ) GB" 
  elif [ "$filesize" -gt 1000000 ] ; then
    fsize="$( echo "scale=2; $filesize/1000000" | bc ) MB" 
  elif [ "$filesize" -gt 1000 ] ; then
    fsize="$( echo "scale=2; $filesize/1000" | bc ) KB" 
  fi
  echo $fsize
}


# Select Disk Volume Dialog
function getdevdisk () {
  # Check for mounted devices in user media folder
  # Parse memcard disk volume Goodies
  memcard=$( df | grep "$mountpath" | awk {'print $1'} | grep "\/dev\/" )
  # Get dev names of drive - remove numbers
  checkdev=$(echo $memcard | sed 's/[0-9]*//g')
  # Remove duplicate dev names
  devdisks=$(echo $checkdev | xargs -n1 | sort -u | xargs )
  # How many devs found
  countdev=$( echo $devdisks | wc -w )
  # Retry detection if no memcards found
  while [ $countdev -eq 0 ] ; do
    notify-send --icon=$iconfile "$apptitle" "No Volumes Detected"
    # Ask for redetect
    zenity --question --title="$apptitle - $action" --text="<big><b>No Volumes Detected</b></big> \n\nInsert a memory card or removable storage and click Retry.\n\nSelect Cancel to Quit" --ok-label=Retry --cancel-label=Cancel --width=400 
    if [ ! $? -eq 0 ] ; then
      exit 1
    fi
    # Do Re-Detection of Devices
    # Parse memcard disk volume Goodies
    memcard=$( df | grep "$mountpath" | awk {'print $1'} | grep "\/dev\/" )
    # Get dev names of drive - remove numbers
    checkdev=$(echo $memcard | sed 's/[0-9]*//g')
    # Remove duplicate dev names
    devdisks=$(echo $checkdev | xargs -n1 | sort -u | xargs )
    # How many devs found
    countdev=$( echo $devdisks | wc -w )
  done

  # Generate Zenity Dialog 
  devdisk=$(
  (
  # Generate list for Zenity
  for (( c=1; c<=$countdev; c++ ))
    do
      devitem=$( echo $devdisks | awk -v c=$c '{print $c}')
      drivesizehuman=$( sudo fdisk -l | grep "Disk $devitem" | cut -d "," -f1 | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')

      echo "$drivesizehuman" ; echo $devitem  
  done

  ) | zenity --list --title="$apptitle - $action : Select your memory card" \
   --column="Volume" --column="Device" --print-column=2 --ok-label=Continue --width=450 --height=200 )
 
  # Return value
  echo $devdisk
}


# Select Backup or Restore if not in args
if [ ! "$action" ] ; then
  response=$(zenity --question --text "\n<big>Select <b>Backup</b> to create an image file from a memory card or disk.\n\n\nSelect <b>Restore</b> to copy an image file to a memory card or disk.</big>\nSupported formats: img, zip, gzip, xz\n\n\n\nWARNING - Use this program with caution. Data could be lost." --title "$apptitle $version" --ok-label=Restore --cancel-label=Backup --width=640 --height=300 )

  if [ $? -eq 0 ] ; then
    action="Restore"
  else
    action="Backup"
  fi
fi

### BACKUP : Select inputfile and outputfile
if [ "$action" == "Backup" ] ; then
  
  # Get memcard device name
  devdisk=$( getdevdisk )
   
  # Cancel if user selects Cancel
    if [ ! $devdisk ] ; then
      notify-send --icon=$iconfile "$apptitle" "No Volumes Selected. $action Cancelled. "
      exit 0
    fi

  # Get output folder for backup image
  imagepath=$(zenity --file-selection --filename=/home/$SUDO_USER/Desktop/ --save --confirm-overwrite --title="$apptitle - $action : Select the filename and folder for memory card image file" --file-filter="*.img *.zip" )
 
  # Cancel if user selects Cancel
  if [ ! $? -eq 0 ] ; then
    notify-send --icon=$iconfile "$apptitle" "$action Cancelled"
    exit 0
  fi

  # Get filename for for backup image and Strip path if given
  filename=$(basename "$imagepath")

  # check if compression implied in filename extension
  extension="${filename##*.}"
  # Check if extension is already zip
  if [ "$extension" == "zip" ] ; then
     compression="Yes"
  else
    # Ask for compression if not a zip file
    zenity --question --title="$apptitle - $action" --text="<big><b>Compress the Backup image file?</b></big> \n\nThis can significantly reduce the space used by the backup." --ok-label=Yes --cancel-label=No --width=400 

    if [ $? -eq 0 ] ; then
      compression="Yes"
    else
      compression="No"
    fi
  fi

  # Parse vars for dd
  outputfile="$imagepath"
  # Add img extension if missing
  if [ "$extension" != "zip" ] && [ "$extension" != "img" ] ; then
    outputfile="$outputfile.img"
  fi
  # Add zip for compressed backup
  if [ "$compression" == "Yes" ] && [ "$extension" != "zip" ] ; then    
    outputfile="$outputfile.zip"
  fi

  # Check if image file exists again
  if [ -f "$outputfile" ] && [ "$imagepath" != "$outputfile" ] ; then
    zenity --question --title="$apptitle - $action" --text="<big><b>The file $outputfile already exist.</b></big>\n\nSelect <b>Continue</b> to overwrite the file.\n\nSelect <b>Cancel</b> to Quit" --ok-label=Continue --cancel-label=Cancel --width=500 
    
    # Cancel if user selects Cancel
    if [ ! $? -eq 0 ] ; then
      notify-send --icon=$iconfile "$apptitle" "$action Cancelled"
      exit 0
    fi

    # Delete the file if exists
    rm $outputfile
  fi

fi


### RESTORE : Select image file and memcard location
if [ "$action" == "Restore" ] ; then

  # Get image file location
  imagepath=$(zenity --file-selection --filename=/home/$SUDO_USER/ --title="$apptitle - $action : Select image file to restore to memory card. Supported file formats : IMG, ZIP, GZ, XZ" --file-filter="*.img *.gz *.xz *.zip")
 
  # Cancel if user selects Cancel
  if [ ! $? -eq 0 ] ; then
    notify-send --icon=$iconfile "$apptitle" "$action Cancelled"
    exit 0
  fi

  # Get memcard device name
  devdisk=$( getdevdisk )
   
  # Cancel if user selects Cancel
    if [ ! $devdisk ] ; then
      notify-send --icon=$iconfile "$apptitle" "$action Cancelled"
      exit 0
    fi

  # Parse vars for dd
  inputfile="$imagepath"

  # Check if Compressed from extension
  extension="${inputfile##*.}"
  if [ "$extension" == "gz" ] || [ "$extension" == "zip" ] || [ "$extension" == "xz" ]; then
    compression="Yes"
  else
    compression="No"
  fi

fi

# Get Drive size in bytes and human readable
drivesize=$( sudo fdisk -l | grep "Disk $devdisk" | cut -d " " -f5 )
drivesizehuman=$( sudo fdisk -l | grep "Disk $devdisk" | cut -d "," -f1 | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')

# Set output option
if [ "$action" == "Backup" ] ; then
  inputfile=$devdisk
  source="<big><b>$drivesizehuman Volume</b></big>    \n $devdisk"
  dest="<big><b>$(basename "$outputfile")</b></big>   \n $(dirname "$outputfile")"
  progressbytes=$drivesize
  # Check available space left for backup
  outputspace=$( df $(dirname "$outputfile") | grep "\/dev\/" | awk {'print $4'} )
  # Output of df is in 1024 K blocks 
  outputspace=$(( $outputspace * 1024 ))
fi
if [ "$action" == "Restore" ] ; then
  inputfilesize=$( du -b "$inputfile" | awk {'print $1'} )
  inputfilesizehuman=$( filesizehuman $inputfilesize )
  source="<big><b>$(basename "$inputfile")</b></big>    $inputfilesizehuman \n $(dirname "$inputfile")"
  dest="<big><b>$drivesizehuman Volume</b></big>    \n $devdisk"
  outputfile=$devdisk
  outputspace=$drivesize
  # Get uncompressed size of image restore files 
  case "$extension" in
    img)
       progressbytes=$inputfilesize
       ;;
    zip)
       progressbytes=$( unzip -l "$inputfile" | tail -1 | awk '{print $1}')
       ;;
     gz)
       progressbytes=$( gzip -l "$inputfile" | tail -1 | awk '{print $2}')
       ;;
     xz)
       progressbytes=$( xz -lv  "$inputfile" | grep "Uncompressed" | cut -d "(" -f2 | cut -d "B" -f1 | sed -e 's/[^0-9]*//g')
       ;;
  esac 
fi

# Check sizes to find out if there is enough space to do backup or restore
if [ "$progressbytes" -gt "$outputspace" ] ; then
  sizedif=$(( $progressbytes - $outputspace ))
  sizedifhuman=$( filesizehuman $sizedif )

  if [ "$compression" == "Yes" ] && [ "$action" == "Restore" ] ; then
    compressflag=" uncompressed"
  fi
  # Add Warning text 
  warning="<b>WARNING: </b>The$compressflag ${action,,} file is <b>$sizedifhuman</b> too big to fit on the destination storage device. You can click Start to continue anyway, or select Cancel to Quit."

fi 
  
# Confirmation Dialog
zenity --question --text="<big>Please confirm settings and click Start</big>\n\n\nSource \n$source \n\nDestination \n$dest \n\n\n$warning\n\n\n<b>NOTE: </b>All Data on the Destination will be deleted and overwritten." --title "$apptitle - $action" --ok-label=Start --cancel-label=Cancel --width=580

# Cancel if user selects Cancel
if [ ! $? -eq 0 ] ; then
  notify-send --icon=$iconfile "$apptitle" "$action Cancelled"
  exit 0
fi

# Unmount mounted partitions
partitions=$( df | grep $devdisk | awk '{print $1}' )
if [ "$partitions" ] ; then
  umount $partitions
fi

# Check mounted patitions again to make sure they are unmounted
partitions=$( df | grep -c $devdisk )

# Cancel if unable to unmount
if [ ! $partitions -eq 0 ] ; then
  notify-send --icon=$iconfile "$apptitle" "Cannot Unmount $devdisk"
  exit 0
fi

# Start dd copy
notify-send --icon=$iconfile "$apptitle" "$drivesizehuman Volume $action Started" 

# No Compression - Backup and Restore to img
if [ "$compression" == "No" ] ; then
  (
   dd if="$inputfile" bs=1M | pv -n -s $progressbytes | dd of="$outputfile" bs=1M 
   echo "# $action Complete. Click Done to exit."
  ) 2>&1 | zenity --progress --title="$apptitle - $drivesizehuman Volume $action" --width=400 --text="$action in progress..."

fi

# Compression Backup and Restore
if [ "$compression" == "Yes" ] ; then
  # Compressed Backup to ZIP file
  if [ "$action" == "Backup" ] ; then
    (
     dd if="$inputfile" bs=1M | pv -n -s $progressbytes | zip > "$outputfile" 
     echo "# $action Complete. Click Done to exit."
    ) 2>&1 | zenity --progress --title="$apptitle - $drivesizehuman Volume $action" --width=400 --text="$action in progress..." --ok-label=Done
    
  fi

  # Compressed Restore
  if [ "$action" == "Restore" ] ; then
    # GZ files
    if [ "$extension" == "gz" ] ; then
      # Pipe to dd
      ( 
       gzip -dc "$inputfile" | pv -n -s $progressbytes | dd of="$outputfile" bs=1M
       echo "# $action Complete. Click Done to exit."
      ) 2>&1 | zenity --progress --title="$apptitle - $drivesizehuman Volume $action" --width=400 --text="$action in progress..." --ok-label=Done
    fi
    # ZIP files
    if [ "$extension" == "zip" ] ; then
      # Pipe to dd
      ( 
       unzip -p "$inputfile" | pv -n -s $progressbytes | dd of="$outputfile" bs=1M 
       echo "# $action Complete. Click Done to exit."
      ) 2>&1 | zenity --progress --title="$apptitle - $drivesizehuman Volume $action" --width=400 --text="$action in progress..." --ok-label=Done
    fi
    # XZ files 
    if [ "$extension" == "xz" ] ; then
      # Pipe to dd
      ( 
       tar -xJOf "$inputfile" | pv -n -s $progressbytes | dd of="$outputfile" bs=1M 
       #xz -dc "$inputfile" | pv -n -s $progressbytes | dd of="$outputfile" bs=1M 
       echo "# $action Complete. Click Done to exit."
      ) 2>&1 | zenity --progress --title="$apptitle - $drivesizehuman Volume $action" --width=400 --text="$action in progress..." --ok-label=Done
    fi
  fi
fi

# check if job was cancelled 
if [ ! $? -eq 0 ] ; then
  notify-send --icon=$iconfile "$apptitle" "$drivesizehuman Volume $action Cancelled"
  # kill jobs
  trap 'kill $(jobs -pr)' SIGINT SIGTERM EXIT
fi

# set permissions
if [ "$action" == "Backup" ] ; then  
  chown $SUDO_USER "$outputfile"
fi

# Copy Complete
# Display Notifications
notify-send --icon=$iconfile "$apptitle" "$drivesizehuman Volume $action Complete"


# kill dd and exit
pkill -x dd
exit 0
# END
