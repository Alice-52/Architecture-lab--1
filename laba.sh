#!/bin/bash
#Принимаем в качестве аргумента путь к папке
dir="$1"
#Проверяем существование папки
if [ -d "$dir" ];
then
 echo "Folder exists, resuming work..."
else
 while [ ! -d "$dir" ];
 do
  echo "Folder doesn't exists, try again or enter EXIT."
  read dir
  
  if [[ "$dir" == "EXIT" ]]; then
   echo "Exiting the programm.."
   exit 0
  fi

 done
 echo "Folder exists, resuming work..."
fi

#Создание ограниченной папки - 10MB, потому что так захотелось




#Считаем размер папки
let "folder_size = $(du -s $dir | cut -f1) / 100"

echo "The size of the folder is, out of 10M we've limited your folder to :) "
du -sh $dir

#Берём проценты для архивирования
echo "How full is your folder in percents: $folder_size%"
echo "What is your preferable threshold of fullness in percents?"
read border


#Архивация
if [ "$folder_size" -gt "$border" ]; then
 echo "Too much memory taken, starting the clearing process..."
#Сколько файлов убрать 
 echo "How many files do you want us to clear?"
 read amount

#Пользователь даёт папку, куда отправить  тары файлов
 echo "Where do you want us to place backups for your files?"
 read b_dir

#Опять проверка существования папки
 if [ -d "$b_dir" ];
 then
  echo "Folder exists, resuming work..."
 else
  while [ ! -d "$b_dir" ];
  do
   echo "Folder doesn't exists, try again or enter EXIT."
   read b_dir

   if [[ "$b_dir" == "EXIT" ]]; then
    echo "Exiting the programm.."
    exit 0
   fi

  done
  echo "Folder exists, resuming work..."
 fi

#Показываем старые файлы
 old_files=$(find "$dir" -type f -printf '%T+ %p\n' | sort | head -n "$amount" | cut -d ' ' -f 2-)
 echo "LIST: $old_files"

 if [ -z "$old_files" ]; then
 echo "Archive list is empty"
 exit 0
 fi

#Создаём тары из старых файлов и удаляем их

 just_file="$b_dir/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
 tar -czf "$just_file" $old_files
 
 rm $old_files

 echo "Archivation done to $just_file and removed from $dir"

else
 echo "Your folder is not that full, exiting the programm."
fi

#Убираем маунт и удаляем образ диска




