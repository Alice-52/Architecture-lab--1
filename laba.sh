#!/bin/bash
# our comment is here
echo "Please enter directory path to the file:"

dir="$1"
if [ -d "$dir" ];
then
 echo "Folder exists, resuming work..."
else
 while [ ! -d "$dir" ];
 do
  echo "Folder doesn't exists, try again."
  read dir
 done
fi

let "folder_size = $(du -s $dir | cut -f1) / 100"

echo "The size of the folder is, out of 10M we've limited your folder to :) "
du -sh $dir

echo "How full is your folder in percents: $folder_size%"
echo "What is your preferable threshold of fullness in percents?"
read border


if [ "$folder_size" -gt "$border" ]; then
 echo "Too much memory taken, starting the clearing process..."
 echo "How many files do you want us to clear?"
 read amount

 echo "Where do you want us to place backups for your files?"
 read b_dir

 old_files=$(find "$dir" -type f -printf '%T+ %p\n' | sort | head -n "$amount" | cut -d ' ' -f 2-)
 echo "LIST: $old_files"

 if [ -z "$old_files" ]; then
 echo "Archive list is empty"
 exit 0
 fi

 just_file="$b_dir/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
 tar -czf "$just_file" $old_files
 rm $old_files

 echo "Archivation done to $just_file and removed from $dir"

else
 echo "Everything is a'right, old sport. Not today..not today..."
fi


