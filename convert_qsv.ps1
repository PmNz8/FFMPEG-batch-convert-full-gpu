$path = ""
$target = ""
$ffmpeg = "C:\Program Files\Jellyfin\Server"

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
        New-Item -ItemType Directory -Path "$targetFull"

        $file_list = Get-ChildItem -Path $path -Include *.mkv -File -Recurse

        foreach($file in $file_list)
        {
            #Write-Host "$($file.FullName)"
            $addon = "$($file.BaseName).hevc$($file.Extension)"
            #Write-Host "$($targetFull)\$($addon)"
            & $ffmpeg\ffmpeg.exe -y -init_hw_device d3d11va=dx11:,vendor=0x8086 -init_hw_device qsv=qs@dx11 -filter_hw_device qs -hwaccel d3d11va -hwaccel_output_format d3d11 -i file:$($file.FullName) -map 0 -c:a copy -c:s copy -map -0:v:1 -threads 0 -codec:v:0 hevc_qsv -low_power 0 -preset veryfast -global_quality 23 -look_ahead 1 -look_ahead_depth 80 -vf "hwmap=derive_device=qsv,scale_qsv=format=p010" -profile:v main10 "$($targetFull)\$($addon)"

        }

    }
}
