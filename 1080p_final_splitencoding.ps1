# Reading the configuration file in JSON format
$config = Get-Content .\config.json | ConvertFrom-Json

Write-Host "Configuration loaded. FFMPEG path: $($config.FFMPEG)"
Write-Host "FFPROBE path: $($config.FFPROBE)"
Write-Host "Audio Conversion: $($config.CONVERT_AUDIO), Bitrate: $($config.AUDIO_BITRATE), Codec: $($config.AUDIO_CODEC)"
Write-Host "Video Conversion: $($config.CONVERT_VIDEO), Quality: $($config.VIDEO_QUALITY), Preset: $($config.VIDEO_PRESET)"

# Validation of FFMPEG and FFPROBE paths
if (-not (Test-Path $config.FFMPEG)) {
    Write-Host "Invalid FFMPEG path. Check config."
    exit
}
elseif (-not (Test-Path $config.FFPROBE)) {
    Write-Host "Invalid FFPROBE path. Check config."
    exit
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
    $ffprobeOutput = & $($config.FFPROBE) -v error -select_streams a -show_entries "stream=index,codec_name,codec_type,bit_rate,channels" -of json $inputFile | Out-String

    # Converting the JSON string to an object
    $ffprobeObject = $ffprobeOutput | ConvertFrom-Json

    # Extracting only the streams part and display
    $tracks = $ffprobeObject.streams
    #$tracks | Format-Table -AutoSize

    return $tracks
}

function Extract-SubtitleTracks {
    param (
        [string]$inputFile
    )

    # Running ffprobe and capturing the output as JSON
    $ffprobeOutput = & $($config.FFPROBE) -v error -select_streams s -show_entries "stream=index,codec_name,codec_type" -of json $inputFile | Out-String

    # Converting the JSON string to an object
    $ffprobeObject = $ffprobeOutput | ConvertFrom-Json

    # Extracting only the streams part and display
    $tracks = $ffprobeObject.streams
    #$tracks | Format-Table -AutoSize

    foreach ($track in $tracks) { 
       $subtitles = $subtitles + "-map 0:$($track.index) -c:$($track.index) copy "
    }

    Write-Host $subtitles
    return $subtitles
}

function Process-AudioTracks {
    param (
        $tracksArray
    )

    foreach ($track in $tracksArray) {
        if ($config.CONVERT_AUDIO -eq "true") {
            if ($track.codec_name.Contains("dts") -or $track.codec_name.Contains("truehd")) {
                if ($track.channels -gt 5) {
                    $command = $command + "-map 0:$($track.index) -c:$($track.index) $($config.AUDIO_CODEC) -ac:$($track.index) 6 -b:$($track.index) $($config.AUDIO_BITRATE) "
                } else {
                    $command = $command + "-map 0:$($track.index) -c:$($track.index) $($config.AUDIO_CODEC) -ac:$($track.index) $($track.channels) -b:$($track.index) $($config.AUDIO_BITRATE) "
                }
                Write-Host "DTS or TrueHD track found, preparing conversion command for track index $($trackid)"
            } elseif ($track.codec_name.Contains("ac3")) {
                if ([int]$track.bit_rate -gt 350000) {
                    if ($track.channels -gt 5) {
                        $command = $command + "-map 0:$($track.index) -c:$($track.index) $($config.AUDIO_CODEC) -ac:$($track.index) 6 -b:$($track.index) $($config.AUDIO_BITRATE) "
                    } else {
                        $command = $command + "-map 0:$($track.index) -c:$($track.index) $($config.AUDIO_CODEC) -ac:$($track.index) $($track.channels) -b:$($track.index) $($config.AUDIO_BITRATE) "
                    }
                } else {
                    $command = $command + "-map 0:$($track.index) -c:$($track.index) copy "
                }
            } elseif ($track.codec_name.Contains("mp3") -or $track.codec_name.Contains("aac") -or $track.codec_name.Contains("flac")) {
                if ([int]$track.bit_rate -gt 350000) {
                    if ($track.channels -gt 5) {
                        $command = $command + "-map 0:$($track.index) -c:$($track.index) $($config.AUDIO_CODEC) -ac:$($track.index) 6 -b:$($track.index) $($config.AUDIO_BITRATE) "
                    } else {
                        $command = $command + "-map 0:$($track.index) -c:$($track.index) $($config.AUDIO_CODEC) -ac:$($track.index) $($track.channels) -b:$($track.index) $($config.AUDIO_BITRATE) "
                    }
                } else {
                $command = $command + "-map 0:$($track.index) -c:$($track.index) copy "
                }
            } else {
                $command = $command + "-map 0:$($track.index) -c:$($track.index) copy "
            }
        } else {
            $command = $command + "-map 0:$($track.index) -c:$($track.index) copy "
        }
    }
    Write-Host "Audio conversion command: $command"
    return $command
}

function Process-File {
    param (
        [string]$inputFile
    )
    # Insert audio track extraction and FFmpeg command construction here
    $audioTracks = Extract-AudioTracks $inputFile
    $audioCommand = Process-AudioTracks $audioTracks
	$subtitleTracks = Extract-SubtitleTracks $inputFile
    if ($config.CONVERT_VIDEO -eq "true") {
        $videoTrack = Extract-VideoTrack $inputFile
        $videoCommand = Process-VideoTrack $videoTrack
    }
    $outputFile = Build-OutputFilename $inputFile
    $ffmpegCommand = Build-FfmpegCommand -subtitles $subtitleTracks -audioCommand $audioCommand -videoCommand $videoCommand -inputFile $inputFile -outputFile $outputFile
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
        "*h264*" { $videoCodec = $($videoCodec + "_cuvid"); Write-Host "H264 video codec found." }
        "*hevc*" { $videoCodec = $($videoCodec + "_cuvid"); Write-Host "HEVC video codec found." }
        "*vc1*"  { $videoCodec = $($videoCodec + "_cuvid"); Write-Host "VC-1 video codec found." }
    }

    Write-Host "Decode GPU acceleraction for codec: $videoCodec"
    return $videoCodec
}

function Build-FfmpegCommand {
    param (
        [string]$audioCommand,
        [string]$videoCommand,
        [string]$inputFile,
        [string]$outputFile,
        [string]$subtitles
    )
    # Function logic goes here
    # -loglevel error -stats 

    $command = " -y "
    if ($videoCommand -ne "") {
        $command = $command + "-hwaccel cuda -hwaccel_output_format cuda -c:V:0 $videoCommand "
    }
    $command = $command + "-i `"$inputFile`" -map 0:V -map_metadata 0 -c:d copy "
    if ($config.CONVERT_VIDEO -eq "true") {
        $command = $command + " -c:V:0 hevc_nvenc -cq $($config.VIDEO_QUALITY) -preset $($config.VIDEO_PRESET) -vf scale_cuda=format=p010le -split_encode_mode 2"
    } else {
        $command = $command + "-c:V:0 copy"
    }
    $command = "$command $audioCommand $subtitles"
    $command = "$command`"$outputFile`" "
    Write-Host $command
    return $command
}

function Build-OutputFilename {
    param (
        [string]$inputFile
    )

    Write-Host "Preparing output file path..."
    if ($inputFile.Contains("mp4")) {
        $outputFile = $inputFile.Replace(".mp4", ".conv.mp4") 
    }
    elseif ($inputFile.Contains("mkv")) {
        $outputFile = $inputFile.Replace(".mkv", ".conv.mkv")
    }
    Write-Host "Output will be saved to: $outputFile"

    return $outputFile
}

function Execute-FfmpegCommand {
    param (
        [string]$command
    )

    $arguments = $command -split ' '

    & $($config.FFMPEG) $arguments
}

# Prompting for input directory
$inputDirectory = Get-ValidDirectory

# Listing files in the input directory
$files = Get-VideoFiles $inputDirectory

# Further script processing based on the files and configurations...

foreach ($file in $files) {
    Write-Host "Processing file: $file"
    Process-File $file.FullName
}