# Reading the configuration file in JSON format
$config = Get-Content .\config_gui.json | ConvertFrom-Json
$files = $null

Write-Host "Configuration loaded. FFMPEG path: $($config.FFMPEG)"
Write-Host "FFPROBE path: $($config.FFPROBE)"
Write-Host "Audio Conversion: $($config.CONVERT_AUDIO), Bitrate: $($config.AUDIO_BITRATE), Codec: $($config.AUDIO_CODEC)"
Write-Host "Video Conversion: $($config.CONVERT_VIDEO), Quality: $($config.VIDEO_QUALITY)"

# Validation of FFMPEG and FFPROBE paths
if (-not (Test-Path $config.FFMPEG)) {
    Write-Host "Invalid FFMPEG path. Check config."
    exit
}
elseif (-not (Test-Path $config.FFPROBE)) {
    Write-Host "Invalid FFPROBE path. Check config."
    exit
}

# Funkcja waliduj¹ca wartoœæ w TextBox Video
function ValidateInputVQ([System.Object]$sender, [System.EventArgs]$e) {
    try {
        # Konwersja tekstu na liczbê
        $value = [int]$sender.Text

        # Sprawdzanie, czy wartoœæ mieœci siê w przedziale od 0 do 51
        if ($value -lt 1 -or $value -gt 51) {
            throw "Poza zakresem"
        }
    }
    catch {
        # Ustawienie tekstu na wartoœæ domyœln¹ w przypadku b³êdu
        $sender.Text = "32"
    }
}

# Funkcja waliduj¹ca wartoœæ w TextBox Audio
function ValidateInputAQ([System.Object]$sender, [System.EventArgs]$e) {
    try {
        # Konwersja tekstu na liczbê
        $value = [int]$sender.Text

        # Sprawdzanie, czy wartoœæ mieœci siê w przedziale od 0 do 51
        if ($value -lt 1 -or $value -gt 768) {
            throw "Poza zakresem"
        }
    }
    catch {
        # Ustawienie tekstu na wartoœæ domyœln¹ w przypadku b³êdu
        $sender.Text = "256"
    }
}

function Get-ValidDirectory {
    do {
        $inputDirectory = Read-Host "Please enter a valid directory path"
        $isValid = Test-Path $inputDirectory -PathType Container
        if (-not $isValid) {
            Write-Host "Invalid directory. Please try again."
        }
    } while (-not $isValid)
    return $inputDirectory
}

function Get-VideoFiles {
    param (
        [string]$directory
    )
    return @("*.mp4", "*.mkv") | ForEach-Object { Get-ChildItem -Path $directory -Filter $_ -File }
}

function Extract-AudioTracks {
    param (
        [string]$inputFile
    )

    # Running ffprobe and capturing the output as JSON
    $audioTrackJson = & $($config.FFPROBE) -v error -select_streams a -show_entries "stream=index,codec_name,codec_type,bit_rate,channels" -of json $inputFile | Out-String

    # Converting the JSON string to an object
    $audioTrackData = $audioTrackJson | ConvertFrom-Json

    # Extracting only the streams part and display
    $audioTracks = $audioTrackData.streams
    #$tracks | Format-Table -AutoSize

    return $audioTracks
}

function Process-AudioTracks {
    param (
        $audioTracks
    )
    if ($radioButton1.Checked -eq $true -and $radioButton2.Checked -eq $false) {
        $audioCodecFromGui = "eac3"
    }
    elseif ($radioButton1.Checked -eq $false -and $radioButton2.Checked -eq $true) {
        $audioCodecFromGui = "aac"
    }
    foreach ($track in $audioTracks) {
        if ($checkbox2.Checked -eq $true) {
            if ($track.codec_name.Contains("dts") -or $track.codec_name.Contains("truehd")) {
                if ($track.channels -gt 5) {
                    $audioConversionCommand = $audioConversionCommand + "-c:$($track.index) $($audioCodecFromGui) -ac:$($track.index) 6 -b:$($track.index) $($textBoxAB.Text)k "
                } else {
                    $audioConversionCommand = $audioConversionCommand + "-c:$($track.index) $($audioCodecFromGui) -ac:$($track.index) $($track.channels) -b:$($track.index) $($textBoxAB.Text)k "
                }
                Write-Host "DTS or TrueHD track found, preparing conversion command for track index $($trackid)"
            } elseif ($track.codec_name.Contains("ac3")) {
                if ([int]$track.bit_rate -gt 350000) {
                    if ($track.channels -gt 5) {
                        $audioConversionCommand = $audioConversionCommand + "-c:$($track.index) $($audioCodecFromGui) -ac:$($track.index) 6 -b:$($track.index) $($textBoxAB.Text)k "
                    } else {
                        $audioConversionCommand = $audioConversionCommand + "-c:$($track.index) $($audioCodecFromGui) -ac:$($track.index) $($track.channels) -b:$($track.index) $($textBoxAB.Text)k "
                    }
                } else {
                    $audioConversionCommand = $audioConversionCommand + "-c:$($track.index) copy "
                }
            } elseif ($track.codec_name.Contains("mp3") -or $track.codec_name.Contains("aac") -or $track.codec_name.Contains("flac")) {
                if ([int]$track.bit_rate -gt 350000) {
                    if ($track.channels -gt 5) {
                        $audioConversionCommand = $audioConversionCommand + "-c:$($track.index) $($audioCodecFromGui) -ac:$($track.index) 6 -b:$($track.index) $($textBoxAB.Text)k "
                    } else {
                        $audioConversionCommand = $audioConversionCommand + "-c:$($track.index) $($audioCodecFromGui) -ac:$($track.index) $($track.channels) -b:$($track.index) $($textBoxAB.Text)k "
                    }
                } else {
                $audioConversionCommand = $audioConversionCommand + "-c:$($track.index) copy "
                }
            } else {
                $audioConversionCommand = $audioConversionCommand + "-c:$($track.index) copy "
            }
        } else {
            $audioConversionCommand = $audioConversionCommand + "-c:$($track.index) copy "
        }
    }
    Write-Host "Audio conversion command: $command"
    return $audioConversionCommand
}

function Process-File {
    param (
        [string]$inputFile
    )
    # Insert audio track extraction and FFmpeg command construction here
    $audioTracks = Extract-AudioTracks $inputFile
    $audioCommand = Process-AudioTracks $audioTracks
    if ($checkbox1.Checked -eq $true) {
        $videoTrack = Extract-VideoTrack $inputFile
        $videoCommand = Process-VideoTrack $videoTrack
    }
    $outputFile = Build-OutputFilename $inputFile
    $ffmpegCommand = Build-FfmpegCommand -audioCommand $audioCommand -videoCommand $videoCommand -inputFile $inputFile -outputFile $outputFile
    Execute-FfmpegCommand $ffmpegCommand
    Write-Host "Finished processing of $inputFile"
}

function Extract-VideoTrack {
    param (
        [string]$inputFile
    )
    Write-Host "Extracting video codec information..."
    $videoCodec = & $($config.FFPROBE) -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -i $inputFile
    return $videoCodec
}

function Process-VideoTrack {
    param (
        [string]$videoCodec
    )

    switch -wildcard ($videoCodec) {
        "*h264*" { $videoCodecWithGpuSupport = $($videoCodec + "_cuvid"); Write-Host "H264 video codec found." }
        "*hevc*" { $videoCodecWithGpuSupport = $($videoCodec + "_cuvid"); Write-Host "HEVC video codec found." }
        "*vc1*"  { $videoCodecWithGpuSupport = $($videoCodec + "_cuvid"); Write-Host "VC-1 video codec found." }
    }

    Write-Host "Decode GPU acceleraction for codec: $videoCodec"
    return $videoCodecWithGpuSupport
}

function Build-FfmpegCommand {
    param (
        [string]$audioCommand,
        [string]$videoCommand,
        [string]$inputFile,
        [string]$outputFile
    )
    # Function logic goes here
    # -loglevel error -stats 
    $command = " -y "
    if ($videoCommand -ne "") {
        $command = $command + "-hwaccel cuda -hwaccel_output_format cuda -c:V:0 $videoCommand "
    }
    $command = $command + "-i `"$inputFile`" -map 0 -map_metadata 0 -c:s copy -c:d copy "
    if ($checkbox1.Checked -eq $true) {
        $command = $command + "-c:V:0 hevc_nvenc -cq $($textBoxVQ.Text) -preset p5 -vf scale_cuda=format=p010le"
    } else {
        $command = $command + "-c:V:0 copy"
    }
    $command = "$command $audioCommand "
    $command = "$command`"$outputFile`" "

    return $command
}

function Build-OutputFilename {
    param (
        [string]$inputFile
    )

    Write-Host "Preparing output file path..."
    if ($inputFile.Contains("mp4")) {
        $convertedFileName = $inputFile.Replace(".mp4", ".conv.mp4") 
    }
    elseif ($inputFile.Contains("mkv")) {
        $convertedFileName = $inputFile.Replace(".mkv", ".conv.mkv")
    }
    Write-Host "Output will be saved to: $outputFile"

    return $convertedFileName
}

function Execute-FfmpegCommand {
    param (
        [string]$command
    )

    $arguments = $command -split ' '
    & $($config.FFMPEG) $arguments
}

# Tworzenie g³ównego okna
$form = New-Object System.Windows.Forms.Form
$form.Text = 'My transcode'
$form.Size = New-Object System.Drawing.Size(1280, 800)
# Ustawienie FormBorderStyle, aby uniemo¿liwiæ zmianê rozmiaru okna
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
# Wy³¹czenie przycisku Maksymalizuj
$form.MaximizeBox = $false

# Tworzenie pierwszego GroupBox
$groupBox1 = New-Object System.Windows.Forms.GroupBox
$groupBox1.Text = "Audio Codec:"
$groupBox1.Location = New-Object System.Drawing.Point(10, 90)
$groupBox1.Size = New-Object System.Drawing.Size(120, 70)
$form.Controls.Add($groupBox1)

# Dodawanie RadioButtonów do pierwszego GroupBox

$radioButton1 = New-Object System.Windows.Forms.RadioButton
$radioButton1.Text = "EAC3"
$radioButton1.Top = 20 * 1
$radioButton1.Left = 10
$radioButton1.Checked = $true
$groupBox1.Controls.Add($radioButton1)
$radioButton2 = New-Object System.Windows.Forms.RadioButton
$radioButton2.Text = "AAC"
$radioButton2.Top = 20 * 2
$radioButton2.Left = 10
$groupBox1.Controls.Add($radioButton2)

# Tworzenie drugiego GroupBox
$groupBox2 = New-Object System.Windows.Forms.GroupBox
$groupBox2.Text = "Convert:"
$groupBox2.Location = New-Object System.Drawing.Point(10, 10)
$groupBox2.Size = New-Object System.Drawing.Size(120, 70)
$form.Controls.Add($groupBox2)

# Dodawanie CheckBoxów do drugiego GroupBox

$checkbox1 = New-Object System.Windows.Forms.CheckBox
$checkbox1.Text = "Video"
$checkbox1.Top = 20
$checkbox1.Left = 10
$checkbox1.Checked = $true
$groupBox2.Controls.Add($checkbox1)
$checkbox2 = New-Object System.Windows.Forms.CheckBox
$checkbox2.Text = "Audio"
$checkbox2.Top = 20 * 2
$checkbox2.Left = 10
$checkbox2.Checked = $true
$groupBox2.Controls.Add($checkbox2)

# Tworzenie trzeciego GroupBox
$groupBox3 = New-Object System.Windows.Forms.GroupBox
$groupBox3.Text = "Quality parameters:"
$groupBox3.Location = New-Object System.Drawing.Point(10, 170)
$groupBox3.Size = New-Object System.Drawing.Size(200, 80)
$form.Controls.Add($groupBox3)

# Dodawanie etykiety i pola tekstowego dla VQ
$labelVQ = New-Object System.Windows.Forms.Label
$labelVQ.Text = "Video CQ:"
$labelVQ.Location = New-Object System.Drawing.Point(10, 20)
$labelVQ.Size = New-Object System.Drawing.Size(70, 20)
$groupBox3.Controls.Add($labelVQ)

$textBoxVQ = New-Object System.Windows.Forms.TextBox
$textBoxVQ.Location = New-Object System.Drawing.Point(80, 20)
$textBoxVQ.Size = New-Object System.Drawing.Size(100, 20)
$textBoxVQ.Text = "32"
$groupBox3.Controls.Add($textBoxVQ)

# Dodawanie etykiety i pola tekstowego dla AB
$labelAB = New-Object System.Windows.Forms.Label
$labelAB.Text = "Audio Kbps:"
$labelAB.Location = New-Object System.Drawing.Point(10, 50)
$labelAB.Size = New-Object System.Drawing.Size(70, 20)
$groupBox3.Controls.Add($labelAB)

$textBoxAB = New-Object System.Windows.Forms.TextBox
$textBoxAB.Location = New-Object System.Drawing.Point(80, 50)
$textBoxAB.Size = New-Object System.Drawing.Size(100, 20)
$textBoxAB.Text = "256"
$groupBox3.Controls.Add($textBoxAB)

# Lista plików
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(220, 10)
$listBox.Size = New-Object System.Drawing.Size(1045, 305)
$form.Controls.Add($listBox)

# Wyjœcie FFMPEG
$richTextBox = New-Object System.Windows.Forms.RichTextBox
$richTextBox.Location = New-Object System.Drawing.Point(220, 330) # Ajust the location as needed
$richTextBox.Size = New-Object System.Drawing.Size(1045, 300) # Ajust the size as needed
$richTextBox.ReadOnly = $true
$richTextBox.Multiline = $true
$form.Controls.Add($richTextBox)

# Przycisk do wyboru folderu
$buttonSelectFolder = New-Object System.Windows.Forms.Button
$buttonSelectFolder.Location = New-Object System.Drawing.Point(10, 260)
$buttonSelectFolder.Size = New-Object System.Drawing.Size(120, 20)
$buttonSelectFolder.Text = 'Choose Folder'
$buttonSelectFolder.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $listBox.Items.Clear()
            #Get-ChildItem -Path $folderBrowser.SelectedPath -File | ForEach-Object {
            #    $listBox.Items.Add($_.FullName)
            #} 
            $script:files = Get-VideoFiles $folderBrowser.SelectedPath
            if ($null -eq $files) {
                Write-Host "No MKV/MP4 files in selected directory $($folderBrowser.SelectedPath)"
            } else {
                $richTextBox.Clear()
                foreach ($file in $files) {
                    $listBox.Items.Add($file.FullName)
                }
            }
            
        }
    })
$form.Controls.Add($buttonSelectFolder)

# Przycisk Execute
$buttonExecute = New-Object System.Windows.Forms.Button
$buttonExecute.Location = New-Object System.Drawing.Point(10, 295)
$buttonExecute.Size = New-Object System.Drawing.Size(120, 20)
$buttonExecute.Text = 'Transcode!'
$buttonExecute.Add_click({
        if ($null -ne $files -and ($checkbox2.Checked -ne $false -and $checkbox1.Checked -ne $false)) {
            $richTextBox.Clear()
            foreach ($file in $files) {
                Write-Host "$($file.FullName)"
                $line = "Currently processing: $file"
                $richTextBox.AppendText($line + "`n")
                Process-File $file.FullName
                $line = "Done!"
                $richTextBox.AppendText($line + "`n" + "`n")
            }
        }
    })
$form.Controls.Add($buttonExecute)

# Tworzenie przycisku do zakoñczenia skryptu
$buttonExit = New-Object System.Windows.Forms.Button
$buttonExit.Location = New-Object System.Drawing.Point(10, 330)
$buttonExit.Size = New-Object System.Drawing.Size(120, 20)
$buttonExit.Text = 'Exit'
$buttonExit.Add_Click({
        $form.Close() # Zamkniêcie formularza i zakoñczenie skryptu
    })
$form.Controls.Add($buttonExit)

# Dodanie obs³ugi zdarzeñ do TextBox
$textBoxVQ.add_TextChanged({ ValidateInputVQ $textBoxVQ $null })
$textBoxAB.add_TextChanged({ ValidateInputAQ $textBoxAB $null })

# Ustawianie wartoœci w GUI na podstawie przekazanych danych
if ($config -ne $null) {
    if ($null -ne $config.AUDIO_BITRATE) {
        $textBoxAB.Text = $config.AUDIO_BITRATE
    }
    if ($null -ne $config.VIDEO_QUALITY) {
        $textBoxVQ.Text = $config.VIDEO_QUALITY
    }
    if ($null -ne $config.AUDIO_CODEC) {
        if ($config.AUDIO_CODEC -eq "eac3") {
            $radioButton1.Checked = $true
            $radioButton2.Checked = $false
        }
        elseif ($config.AUDIO_CODEC -eq "aac") {
            $radioButton1.Checked = $false
            $radioButton2.Checked = $true
        }
    }
    if ($null -ne $config.CONVERT_AUDIO) {
        $checkboxValue = [bool]::Parse($config.CONVERT_AUDIO)
        $checkbox1.Checked = $checkboxValue
    }
    if ($null -ne $config.CONVERT_VIDEO) {
        $checkboxValue = [bool]::Parse($config.CONVERT_VIDEO)
        $checkbox2.Checked = $checkboxValue
    }
    # Dodaj wiêcej warunków dla innych kontrolek, jeœli to konieczne
}

# Wyœwietlenie GUI
$form.ShowDialog()