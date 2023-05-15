$path = ""
$target = ""
$ffmpeg = "C:\Program Files\Jellyfin\Server"
$ffprobe = "C:\Program Files\Jellyfin\Server"

while ($path -eq "" -or -not (Test-Path $path)) {
    $path = Read-Host "Please enter a valid source path:"
    $target = Read-Host "Please enter a valid target path:"
    if (-not (Test-Path $path)) {
        Write-Host "Invalid path. Please try again."
    }
    elseif (-not (Test-Path $target)){
        Write-Host "Invalid path. Please try again."
    }
    else
    {
        $parentfolder = (Get-Item $path).Name

        if ($target.EndsWith("\")) {
            $targetFull = "$($target)$($parentfolder).hevc"
        } else {
            $targetFull = "$($target)\$($parentfolder).hevc"   
        }
        #Write-Host "Creating new target directorty: $($targetFull)"
        if (Test-Path $targetFull) {
        } else {
            New-Item -ItemType Directory -Path "$targetFull"
        }

        $file_list = Get-ChildItem -Path $path -Include *.mkv, *.mp4 -File -Recurse

        foreach($file in $file_list)
        {   
            $videoCodec = & $ffprobe\ffprobe.exe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -i file:$($file.FullName)
            switch -wildcard ($videoCodec) {
                "*h264*" { $videoCodec = $($videoCodec+"_cuvid") }
                "*hevc*" { $videoCodec = $($videoCodec+"_cuvid") }
            }
            $addon = "$($file.BaseName).hevc$($file.Extension)"
            Write-Host $videoCodec
            & $ffmpeg\ffmpeg.exe -y -hwaccel cuda -hwaccel_output_format cuda -c:v $videoCodec -i file:$($file.FullName) -map 0 -c:a copy -c:s copy -map -0:v:1 -cq 19 -qmin 1 -qmax 51 -codec:v:0 hevc_nvenc -preset p2 -vf scale_cuda=format=p010le "$($targetFull)\$($addon)"

        }

    }
}