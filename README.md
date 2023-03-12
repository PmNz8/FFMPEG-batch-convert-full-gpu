# FFMPEG-batch-convert-full-gpu
Windows only.
Powershell script to call FFMPEG and convert H264 into H265.

To use this script basiaclly run it, provide folder path with input files:
E:\Series\TWD\S01
and output directory.
E:\Series\TWD\S01
You can use the same input/output directory as script will create new folder and files with .hevc appended before file extension. 

This script will convert MKV files from H264 into H265 using full GPU acceleration - that means decoding, scaling from 8 to 10bit and encoding.
Only video stream is converted, all remaining streams are copied. Video resolution or framerate is not changed, only bitdepth is increased as it provides better gradients with lower bitrate when using 10bit.

This script uses FFMPEG build by https://github.com/jellyfin/jellyfin Jellyfin. 
By default exe is available in your jellyfin server install folder under C:\Program Files\Jellyfin\Server.
I did not test it with other FFMPEG buids, it might or might not work.

This scipt uses Intel Quick Sync Video acceleration.
Many thanks to user https://github.com/nyanmisaka for helping me with getting all these FFMPEG commands right.

Feel free to adjust this script as you need, FFMPEG commands are hardcoded with values that suited my needs for quality.
