# Medra - Media Compression Tool

A clean and efficient iOS app for compressing images, videos, and audio files. Extensive customization options to meet your personalized needs. Runs locally without network, protecting your privacy and security.

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/id6755109910)

## Core Features

- Support batch selection of images, videos, and audio (up to 20 files)
- Support multiple media formats
  - Images: JPEG/PNG/HEIC/WebP/AVIF/GIF
  - Videos: MOV/MP4/M4V
  - Audio: MP3/M4A/AAC/WAV/FLAC/OGG
- Real-time processing progress display
- Intelligent quality protection mechanism

## Three Main Media Types

### 1. Video Tools

#### Video Compression

- Support MOV/MP4/M4V formats
- Use FFmpeg hardware-accelerated encoding (VideoToolbox)
- Support H.264 and H.265/HEVC encoding
- Adjustable resolution (Original/4K/2K/1080p/720p)
- Adjustable frame rate (23.98-60 fps, only supports lowering frame rate)
- Metadata control: preserves container tags by default, when "Preserve Metadata" is disabled, uses FFmpeg `-map_metadata -1` to remove metadata from exported files
- Bitrate control:
  - **Auto Mode** (default): intelligently adjusts based on target resolution
    - 720p ≈ 1.5 Mbps
    - 1080p ≈ 3 Mbps
    - 2K ≈ 5 Mbps
    - 4K ≈ 8 Mbps
  - **Custom Mode**: manually set bitrate (500-15000 kbps)
  - ⚠️ Actual bitrate may be lower than target (VideoToolbox dynamically adjusts based on content complexity to optimize efficiency)
- Smart decision: preserve original file if compressed version is larger

#### Video Format Conversion

- Batch convert video formats: MP4 ↔ MOV ↔ M4V
- Lossless conversion (where possible), maintaining original quality

#### Video to Animation

- Convert video to animated WebP, AVIF, or GIF
- Customizable frame rate (1-30 fps)
- Loop count control
- Quality adjustment

#### Extract Audio

- Extract audio track from video files
- Save as MP3, M4A, AAC, FLAC, WAV, or OGG

### 2. Image Tools

#### Image Compression

- Support JPEG/PNG/HEIC/WebP/AVIF/GIF formats
- Use MozJPEG for high-quality JPEG compression
- PNG compression using pngquant + optional Zopfli (lossy quantization + lossless deflate)
- **Animated WebP/AVIF/GIF Support**:
  - Auto-detect animated files
  - Option to preserve animation or convert to static image
  - Frame-by-frame compression, maintaining timeline information
  - Smart fallback: preserve original file if compressed lossless format is larger
  - Visual indicator: clearly display animation status and frame count
- Adjustable compression quality (10%-100%)
- Support resolution adjustment (Original/4K/2K/1080p/720p)
- Auto orientation detection (landscape/portrait)
- Smart decision: preserve original file if compressed version is larger

#### Image Format Conversion

- Batch convert image formats: JPEG ↔ PNG ↔ WebP ↔ HEIC ↔ AVIF ↔ GIF
- No compression, only format modification

### 3. Audio Tools

#### Audio Compression

- Support MP3/M4A/AAC/WAV/FLAC/OGG input
- Multiple output format options:
  - **Original**: preserve input file format (default)
  - MP3 (libmp3lame)
  - AAC
  - M4A
  - FLAC (lossless)
  - WAV (uncompressed)
  - OGG
- 8 bitrate options (32-320 kbps)
- 7 sample rate options (8-48 kHz)
- Channel selection (mono/stereo)
- Smart quality protection: prevent low-quality audio from being "upscaled"
- Smart decision: preserve original file if compressed version is larger

#### Audio Format Conversion

- Batch convert audio formats: MP3 ↔ M4A ↔ FLAC ↔ WAV
- Lossless conversion (where possible)

#### Audio to Text

- Transcribe audio files to text using Apple's Speech framework
- Support multiple languages (English, Chinese, Japanese, Korean, Spanish, French, German, Italian, Portuguese, Russian)
- Copy transcription to clipboard

#### Text to Speech

- Convert text to audio file
- Support multiple languages and voices
- Adjustable pitch and rate
- Save as audio file

## Contact

For questions or suggestions, please contact: <stormte@gmail.com>
