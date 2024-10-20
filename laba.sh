#!/bin/bash

# Принимаем в качестве аргумента путь к папке
dir="$1"

# Проверяем существование папки
#-d - is a directory(-f - is a file)
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


# Создание ограниченной папки

#Спрашиваем, насколько ограничить
echo "How many megabytes for your folder?"
read lim

#dd - копирование блочных данных с устройства /dev/zero(спец файл - источник  нулевых байтов)
#в файл образа диска; bs - сколько байт читать и записывать
#count - скопировать указанное кол-во блоков, размера bs
dd if=/dev/zero of=limit.img bs=1M count="$lim"

# Создаём файловую систему на нашем образе диска
mkfs.ext4 limit.img

# Создаём маунт поинт
sudo mkdir /mnt/limited_fol

# Монтируем образ
#--options loop - используем loop device(ненастоящее устройство-просто файл) в качестве блочного устройства
#т.к хотим примонтировать файл - образ диска, а не устройство
sudo mount -o loop limit.img /mnt/limited_fol

# Выделяем имя папки для создания символической ссылки
name="$(basename "$dir")"

# Перемещаем нашу директорию в ограниченную папку
sudo mv "$dir" /mnt/limited_fol

# Создаём символическую ссылку, чтобы можно было работать из изначального места
# -s  - soft-link(symbolic)
ln -s /mnt/limited_fol/"$name" "$dir"

# Считаем размер папки
# -s --summarize; -L --dereference links разыменование ссылок внутри
# cut -f1 - вырезаем поле(--fields[переченьLIST]) - название директории
# Двойные скобки для решения арифметических операций
# | - передаёт вывод предыдущей команды на вход следующей
folder_size=$( du -sL "$dir" | cut -f1 )
folder_size=$(( folder_size / $lim ))
folder_size=$(( folder_size / 10 ))  # Преобразуем в мегабайты и проценты

# -h --human-readable format
echo "The size of the folder is, out of "$lim"MB we've limited your folder to :)"
du -shL "$dir"


# Процент заполнения папки
echo "How full is your folder in percents: $folder_size%"
echo "What is your preferable threshold of fullness in percents?"
read border



# Архивация, если размер папки больше порога
# -gt --greater
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

  # В перенесённой папке ищем только файлы(игнорируем директории -type f)
  # -printf '%T + %p\n" - %T выводит дату и время последнего изменения, %p - полный путь к файлу
  # sort - сортирует по дате изменения файлов, т.к. она выводится в предыдущей
  # head -n "$amount" --lines(заданное нами кол-во вместо 10) и наше количество
  # cut обрабатываем наши строки для корректной работы tar
  # -d --delimiter ' ' задаём пробел в качестве разделителя
  # -f 2- начинаем со второго поля, т.к. первое это дата
  old_files=$(find /mnt/limited_fol/"$name" -type f -printf '%T+ %p\n' | sort | head -n "$amount" | cut -d ' ' -f 2-)

  echo -e "LIST:\n $old_files"

  # Проверяем не пустой ли
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
  # Создаём файл в котором директория и название копии
  # backup_ - префикс названия файла
  # date +%Y%m%%d_%H%M%S - дата и время ГГГГММДД_ЧЧММСС - год месяц день_час минута секунды
  # .tar.gz - gzipped tar -
  just_file="$b_dir/backup_$(date +%Y%m%d_%H%M%S).tar.gz"

  # tar архивируем в just_file файлы из олдфайлс
  # -c --create новый создаём
  # -z --gzip направляем вывод в gzip
  # -f --file выводим результат в файл
  tar -czf "$just_file" $old_files

  # Удаляем заархивированные файлы
  rm $old_files

  echo "Archivation done to $just_file and removed from $dir"
else
  echo "Your folder is not that full, exiting the program."
fi

# Убираем созданную символическую ссылку
# -r --recursive - рекурсивно файлы в директориях, а потом сами директории
sudo rm -r "$dir"

# Удаляем перемещённую папку
sudo rm -r /mnt/limited_fol/"$name"

# Размонтируем файловую систему
sudo umount /mnt/limited_fol

# Удаляем маунт поинт
sudo rmdir /mnt/limited_fol

# Удаляем созданный образ диска
rm limit.img
