#!/bin/bash

test_dir="/tmp/test_folder"
backup_dir="/tmp/backup"
non_existent_dir="/tmp/non_existent_folder"

# Функция для генерации файлов в папке до нужного размера (в мегабайтах)
generate_files() {
    folder=$1
    target_size_mb=$2
    target_size=$((target_size_mb * 1024))  # Перевод MB в килобайты

    mkdir -p "$folder"
    current_size=$(du -sk "$folder" | cut -f1)

    while [ "$current_size" -lt "$target_size" ]; do
        # Создание файлов размером 10 MB каждый
        dd if=/dev/zero of="$folder/file_$(date +%s%N).bin" bs=1M count=10 &>/dev/null
        current_size=$(du -sk "$folder" | cut -f1)
    done
    echo "Папка $folder сгенерирована и занимает минимум $target_size_mb MB."
}

check_result() {
    if [ "$1" -eq 0 ]; then
        echo "Тест пройден успешно."
    else
        echo "Тест не пройден."
    fi
}

# Тест 1: Папка существует и весит >= 0.5 GB
test_case_1() {
    echo "Тест 1: Папка существует и весит >= 0.5 GB"

    # Очистка и создание папки
    rm -rf "$test_dir" "$backup_dir"
    mkdir -p "$test_dir" "$backup_dir"

    generate_files "$test_dir" 512  # 512 MB

    /usr/bin/expect <<EOF
        spawn sudo /home/lalisa/laba.sh "$test_dir"
        expect "How many megabytes for your folder?"
        send "1000\r"
        expect "What is your preferable threshold of fullness in percents?"
        send "70\r"
        expect eof
EOF

    check_result $?
    echo
}

test_case_2() {
    echo "Тест 2: Папка не существует и передается EXIT"

    # Очистка перед тестом
    rm -rf "$non_existent_dir" "$backup_dir"
    mkdir -p "$backup_dir"

    /usr/bin/expect <<EOF
        spawn sudo /home/lalisa/laba.sh "$non_existent_dir"
        expect "Folder doesn't exist, try again or enter EXIT."
        send "EXIT\r"
        expect eof
EOF

    check_result $?
    echo
}

test_case_3() {
    echo "Тест 3: Папка весит 1.5 GB"

    rm -rf "$test_dir" "$backup_dir" 
    mkdir -p "$backup_dir"

    generate_files "$test_dir" 1536  # 1536 MB = 1.5 GB

    /usr/bin/expect <<EOF
        spawn sudo /home/lalisa/laba.sh "$test_dir"
        expect "How many megabytes for your folder?"
        send "1000\r"
        expect "Keep the size and lose some files - Y, change the Limit - N."
        send "N\r"
        expect "Type your new limit or enter EXIT."
        send "EXIT\r"
        expect eof
EOF

    check_result $?
    echo
}

test_case_4() {
    echo "Тест 4: Папка весит 900 MB, ограничение 1000 MB, очистка файлов"

    rm -rf "$test_dir" "$backup_dir"
    mkdir -p "$test_dir" "$backup_dir"

    generate_files "$test_dir" 900  # 900 MB

    /usr/bin/expect <<EOF
        spawn sudo /home/lalisa/laba.sh "$test_dir"
        expect "How many megabytes for your folder?"
        send "1000\r"
        expect "The size of the folder is, out of 1000MB we've limited your folder to :)"
        expect "900Mb - /home/lalisa/Laba"
        expect "How full is your folder in percents: 90%"
        expect "What is your preferable threshold of fullness in percents?"
        send "70\r"
        expect "Too much memory taken, starting the clearing process..."
        expect "How many files do you want us to clear?"
        send "20\r"
        expect "Where do you want us to place backups for your files?"
        send "$backup_dir\r"
        expect eof
EOF

    check_result $?
    echo
}

# Запуск тестов
test_case_1
test_case_2
test_case_3
test_case_4