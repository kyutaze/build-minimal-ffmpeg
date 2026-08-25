以下の1〜4の要件をすべて満たす最小限の`ffmpeg`をビルドするスクリプトを調査して提示してください。
1. 以下probe結果を出力する入力ファイルに対して`ffmpeg.exe -i "aaa.mkv" -map 0 -codec:v libx265 -codec:a copy -codec:s copy "bbb.mkv"`を実行できること。
なお、入力ファイルが`mp4`の場合にも対応してください。
```
Input #0, matroska,webm, from 'aaa.mkv':
  Metadata:
    DATE            : 2026-08-24T10:28:56.1931721+09:00
    ENCODER         : Lavf63.1.101
  Duration: 00:15:27.00, start: 0.000000, bitrate: 4098 kb/s
  Stream #0:0: Video: h264 (High), yuv420p(tv, bt709, progressive), 1920x1080 [SAR 1:1 DAR 16:9], 29.97 fps, 29.97 tbr, 1k tbn (default)
    Metadata:
      DURATION        : 00:15:26.992000000
  Stream #0:1: Audio: aac (LC), 48000 Hz, stereo, fltp (default)
    Metadata:
      DURATION        : 00:15:26.997000000
```

2. 以下probe結果を出力する入力ファイルに対して`ffmpeg.exe -i "00000.m2ts" -map 0 -codec:v libx265 -codec:a libfdk_aac "bbb.mkv"`を実行できること。
```
Input #0, mpegts, from '00000.m2ts':
  Duration: 00:00:30.03, start: 4200.000000, bitrate: 5679 kb/s
  Program 1
  Stream #0:0[0x1011]: Video: h264 (High) (HDMV / 0x564D4448), yuv420p(progressive), 1920x1080 [SAR 1:1 DAR 16:9], 23.98 fps, 23.98 tbr, 90k tbn, start 4200.000000
  Stream #0:1[0x1100]: Audio: pcm_bluray (HDMV / 0x564D4448), 48000 Hz, stereo, s32 (24 bit), 2304 kb/s, start 4200.000000
```

3. ビルド環境
    - Ubuntu 26.04 on WSL2
    - できるだけ「使用するディスク容量を小さく」かつ「ビルド時間を短く」したいので、まずは`apt`の`MinGW`をでのビルドを試したい。

4. `FFMpeg`のバージョン
    - FFmpegのソースは、`https://git.ffmpeg.org/ffmpeg.git`の`Tags`（`n9.0.1`など）で指定できること。
    - `Tags`（`n9.0.1`など）をスクリプトの引数で指定できること。
