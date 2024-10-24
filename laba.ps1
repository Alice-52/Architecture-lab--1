# Проверяем, передан ли аргумент
if ($args.Count -eq 0) {
    Write-Host "Please provide a path to the folder as an argument."
    exit 1
}

# Принимаем в качестве аргумента путь к папке
$dir = $args[0]

# Проверяем существование папки
if (-Not (Test-Path $dir -PathType Container)) {
    while (-Not (Test-Path $dir -PathType Container)) {
        Write-Host "Folder doesn't exist, try again or enter EXIT."
        $input = Read-Host
        
        if ($input -eq "EXIT") {
            Write-Host "Exiting the program..."
            exit 0
        } else {
            $dir = $input
        }
    }
    Write-Host "Folder exists, resuming work..."
}

# Запрашиваем размер ограничения папки
$lim = Read-Host -Prompt "How many megabytes do you want to limit your folder to?"

$dum_size = (Get-ChildItem -Path $dir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB

# Предупреждение
if ($dum_size -ge $lim) {
    Write-Host "The size of your folder is bigger than that - $([math]::Round($dum_size, 2)) MB. Are you sure?"
    Write-Host "Keep the size and lose some files - Y, change the limit - N."
    $answer = Read-Host

    if ($answer -eq "N") {
        while ($dum_size -ge $lim) {
            $lim = Read-Host -Prompt "Type your new limit or enter EXIT."
            if ($lim -eq "EXIT") {
                Write-Host "Exiting the program..."
                exit 0
            }
        }
    }
    if ($answer -eq "Y") {
        Write-Host "We will fill the folder to your chosen limit - some files will be DELETED."
    }
}

# Создание виртуального диска
$vhdPath = "C:\HDD\limited.vhd"

try {
    New-VHD -Path $vhdPath -Fixed -SizeBytes ([int]$lim * 1MB)
    Write-Host "Virtual disk created at $vhdPath with a size limit of $lim MB."
} catch {
    Write-Host "Failed to create virtual disk: $_"
    exit 1
}

# Подключение виртуального диска
Mount-VHD -Path $vhdPath

# Получение буквы диска
$disk = Get-Disk | Where-Object { $_.OperationalStatus -eq 'Online' -and $_.PartitionStyle -eq 'Raw' }
if ($disk) {
    $diskNumber = $disk.Number

    # Инициализация диска
    Initialize-Disk -Number $diskNumber -PartitionStyle MBR

    # Создание раздела и форматирование его в NTFS
    $driveLetter = (New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter).DriveLetter
    Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -Confirm:$false

    Write-Host "File system created on the virtual disk."
} else {
    Write-Host "No raw disk found to initialize."
    exit 1
}

# Создаем директорию внутри виртуального диска
$limitedDir = "$driveLetter`:\LimitedFolder"
if (-Not (Test-Path $limitedDir)) {
    New-Item -ItemType Directory -Path $limitedDir
}

# Перемещение файлов из указанной папки
try {
    Move-Item -Path "$dir\*" -Destination $limitedDir -Force
} catch {
    Write-Host "Failed to move items: $_"
    exit 1
}

# Создаем символическую ссылку
$symlinkPath = Join-Path -Path $dir -ChildPath "SymlinkToLimitedFolder"
try {
    cmd.exe /c mklink /D $symlinkPath $limitedDir
    Write-Host "Symbolic link created at $symlinkPath pointing to $limitedDir."
} catch {
    Write-Host "Failed to create symbolic link: $_"
}

# Считаем размер папки
$folderSize = (Get-ChildItem -Path $limitedDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "Total size of the limited folder: $([math]::Round($folderSize, 2)) MB."

# Процент заполнения папки
$usedPercentage = ($folderSize / $lim) * 100
Write-Host "Used space percentage: $([math]::Round($usedPercentage, 2))%."

$border = Read-Host -Prompt "What is your preferable threshold of fullness in percents?"

# Архивация, если размер папки больше порога
if ($usedPercentage -gt $border) {
    Write-Host "Too much memory taken, starting the clearing process..."
	
# Получаем и сортируем все файлы в ограниченной папке
    $oldFiles = Get-ChildItem -Path "$limitedDir" -Recurse | Sort-Object LastWriteTime

    # Получаем общее количество файлов в ограниченной папке
    $totalFiles = (Get-ChildItem -Path "$limitedDir" -Recurse).Count
    Write-Host "Maximum number of files available for archiving: $totalFiles."

    # Выводим все файлы от самого старого до самого нового
    if ($totalFiles -gt 0) {
        Write-Host "Files in the LimitedFolder (sorted from oldest to newest):"
        $oldFiles | ForEach-Object { Write-Host "$($_.FullName) - Last Modified: $($_.LastWriteTime)" }
    } else {
        Write-Host "No files found in the LimitedFolder."
    }

    $amount = Read-Host -Prompt "How many files do you want us to clear?"

    # Цикл для проверки введенного значения
    while ($amount -gt $totalFiles) {
        Write-Host "Error: You cannot archive more files than are present in the folder. Total files: $totalFiles."
        $amount = Read-Host -Prompt "Please enter a valid number of files or type EXIT to quit."

        if ($amount -eq "EXIT") {
            Write-Host "Exiting the program..."

		# Убираем созданную символическую ссылку
		if (Test-Path $symlinkPath) {
  		  Remove-Item $symlinkPath -Force
		}

		# Удаляем перемещённую папку
		Remove-Item $limitedDir -Recurse -Force

		# Размонтируем файловую систему
		Dismount-VHD -Path $vhdPath

		# Удаляем созданный образ диска
		Remove-Item $vhdPath -Force
            exit 0
        }

    }

    $b_dir = Read-Host -Prompt "Where do you want us to place backups for your files?"

    # Проверка существования директории для бэкапов
    if (-Not (Test-Path $b_dir -PathType Container)) {
        while (-Not (Test-Path $b_dir -PathType Container)) {
            Write-Host "Folder doesn't exist, try again or enter EXIT."
            $input = Read-Host
            
            if ($input -eq "EXIT") {
                Write-Host "Exiting the program..."
		# Убираем созданную символическую ссылку
		if (Test-Path $symlinkPath) {
  		  Remove-Item $symlinkPath -Force
		}

		# Удаляем перемещённую папку
		Remove-Item $limitedDir -Recurse -Force

		# Размонтируем файловую систему
		Dismount-VHD -Path $vhdPath

		# Удаляем созданный образ диска
		Remove-Item $vhdPath -Force
                exit 0
            } else {
                $b_dir = $input
            }
        }
        Write-Host "Folder exists, resuming work..."
    }

    # Находим старые файлы в новой директории
    $oldFiles = Get-ChildItem -Path "$limitedDir" -Recurse | Sort-Object LastWriteTime | Select-Object -First $amount

    if ($oldFiles.Count -eq 0) {
        Write-Host "Archive list is empty"
		# Убираем созданную символическую ссылку
		if (Test-Path $symlinkPath) {
  		  Remove-Item $symlinkPath -Force
		}

		# Удаляем перемещённую папку
		Remove-Item $limitedDir -Recurse -Force

		# Размонтируем файловую систему
		Dismount-VHD -Path $vhdPath

		# Удаляем созданный образ диска
		Remove-Item $vhdPath -Force
        exit 0
    }

    Write-Host "LIST:"
    $oldFiles | ForEach-Object { Write-Host $_.FullName }

    # Создаём архив и удаляем старые файлы
    $justFile = Join-Path -Path $b_dir -ChildPath "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
    $oldFiles | ForEach-Object { $_.FullName } | Compress-Archive -DestinationPath $justFile

    # Удаляем заархивированные файлы
    $oldFiles | ForEach-Object { Remove-Item $_.FullName -Force }

    Write-Host "Archiving done to $justFile and removed from $limitedDir"
} else {
    Write-Host "Your folder is not that full, exiting the program."
}

# Убираем созданную символическую ссылку
if (Test-Path $symlinkPath) {
    Remove-Item $symlinkPath -Force
}

# Удаляем перемещённую папку
Remove-Item $limitedDir -Recurse -Force

# Размонтируем файловую систему
Dismount-VHD -Path $vhdPath

# Удаляем созданный образ диска
Remove-Item $vhdPath -Force


