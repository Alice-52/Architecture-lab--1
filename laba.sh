#!/bin/bash

# Принимаем в качестве аргумента путь к папке
dir="$1"

# Проверяем существование папки
if [ -d "$dir" ]; then
  echo "Folder exists, resuming work..."
else
  while [ ! -d "$dir" ]; do
    echo "Folder doesn't exist, try again or enter EXIT."
    read dir

    if [[ "$dir" == "EXIT" ]]; then
      echo "Exiting the program..."
      exit 0
    fi
  done
  echo "Folder exists, resuming work..."
fi

#Спрашиваем, насколько ограничить
echo "How many M for your folder?"
read lim

# Создание ограниченной папки
dd if=/dev/zero of=limit.img bs=1M count="$lim"

# Создаём файловую систему на нашем образе диска
mkfs.ext4 limit.img

# Создаём маунт поинт
sudo mkdir /mnt/limited_fol

# Монтируем образ
sudo mount -o loop limit.img /mnt/limited_fol

# Выделяем имя папки для создания символической ссылки
name="$(basename "$dir")"

# Перемещаем нашу директорию в ограниченную папку
sudo mv "$dir" /mnt/limited_fol

# Создаём символическую ссылку, чтобы можно было работать из изначального места
ln -s /mnt/limited_fol/"$name" "$dir"

# Считаем размер папки
folder_size=$( du -sL "$dir" | cut -f1 )
folder_size=$(( folder_size / $lim ))
folder_size=$(( folder_size / 10 ))  # Преобразуем в мегабайты

echo "The size of the folder is, out of "$lim"MB we've limited your folder to :)"
du -shL "$dir"

# Процент заполнения папки
echo "How full is your folder in percents: $folder_size%"
echo "What is your preferable threshold of fullness in percents?"
read border

# Архивация, если размер папки больше порога
if [ "$folder_size" -gt "$border" ]; then
  echo "Too much memory taken, starting the clearing process..."
  echo "How many files do you want us to clear?"
  read amount

  echo "Where do you want us to place backups for your files?"
  read b_dir

  # Проверка существования директории для бэкапов
  if [ -d "$b_dir" ]; then
    echo "Folder exists, resuming work..."
  else
    while [ ! -d "$b_dir" ]; do
      echo "Folder doesn't exist, try again or enter EXIT."
      read b_dir

      if [[ "$b_dir" == "EXIT" ]]; then
        echo "Exiting the program..."
        # Убираем созданную символическую ссылку
	sudo rm "$dir"

	# Удаляем перемещённую папку
	sudo rm -r /mnt/limited_fol/"$name"

	# Размонтируем файловую систему
	sudo umount /mnt/limited_fol

	# Удаляем маунт поинт
	sudo rmdir /mnt/limited_fol

	# Удаляем созданный образ диска
	rm limit.img

	exit 0
      fi
    done
    echo "Folder exists, resuming work..."
  fi

  # Находим старые файлы
  old_files=$(find /mnt/limited_fol/"$name" -type f -printf '%T+ %p\n' | sort | head -n "$amount" | cut -d ' ' -f 2-)

  echo "LIST: $old_files"

  if [ -z "$old_files" ]; then
    echo "Archive list is empty"
	# Убираем созданную символическую ссылку
	sudo rm -r "$dir"

	# Удаляем перемещённую папку
	sudo rm -r /mnt/limited_fol/"$name"

	# Размонтируем файловую систему
	sudo umount /mnt/limited_fol

	# Удаляем маунт поинт
	sudo rmdir /mnt/limited_fol

	# Удаляем созданный образ диска
	rm limit.img
    exit 0
  fi

  # Создаём архив и удаляем старые файлы
  just_file="$b_dir/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
  tar -czf "$just_file" $old_files

  rm $old_files
  echo "Archivation done to $just_file and removed from $dir"
else
  echo "Your folder is not that full, exiting the program."
fi

# Убираем созданную символическую ссылку
sudo rm -r "$dir"

# Удаляем перемещённую папку
sudo rm -r /mnt/limited_fol/"$name"

# Размонтируем файловую систему
sudo umount /mnt/limited_fol

# Удаляем маунт поинт
sudo rmdir /mnt/limited_fol

# Удаляем созданный образ диска
rm limit.img
