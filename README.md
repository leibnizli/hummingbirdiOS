# Medra - Media Compression Tool

A clean and efficient iOS app for compressing images, videos, and audio files. Extensive customization options to meet your personalized needs. Runs locally without network, protecting your privacy and security.

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/id6755109910)

## Core Features

- Support batch selection of images, videos, and audio (up to 20 files)
- Support multiple media formats
  - Images: JPEG/PNG/HEIC/WebP/AVIF
  - Videos: MOV/MP4/M4V
  - Audio: MP3/M4A/AAC/WAV/FLAC/OGG
- Real-time processing progress display
- Intelligent quality protection mechanism

## Three Main Modules

### 1. Compression

#### Image Compression

- Support JPEG/PNG/HEIC/WebP/AVIF formats
- Use MozJPEG for high-quality JPEG compression
- PNG compression using pngquant + optional Zopfli (lossy quantization + lossless deflate)
- **Animated WebP Support**:
  - Auto-detect animated WebP (multi-frame)
  - Option to preserve animation or convert to static image
  - Frame-by-frame compression, maintaining timeline information
  - Smart fallback: preserve original file if compressed lossless format is larger
  - Visual indicator: clearly display animation status and frame count
- **Animated AVIF Support**:
  - Auto-detect animated AVIF
  - Option to preserve original animation (pass-through) or convert to static image
- Adjustable compression quality (10%-100%)
- Support resolution adjustment (Original/4K/2K/1080p/720p)
- Auto orientation detection (landscape/portrait)
- Smart decision: preserve original file if compressed version is larger

#### Video Compression

- Support MOV/MP4/M4V formats
- Use FFmpeg hardware-accelerated encoding (VideoToolbox)
- Support H.264 and H.265/HEVC encoding
- Adjustable resolution (Original/4K/2K/1080p/720p)
- Adjustable frame rate (23.98-60 fps, only supports lowering frame rate)
- Metadata control: preserves container tags by default, when "Preserve Metadata" is disabled, uses FFmpeg \`-map_metadata -1\` to remove metadata from exported files
- Bitrate control:
  - **Auto Mode** (default): intelligently adjusts based on target resolution
    - 720p ≈ 1.5 Mbps
    - 1080p ≈ 3 Mbps
    - 2K ≈ 5 Mbps
    - 4K ≈ 8 Mbps
  - **Custom Mode**: manually set bitrate (500-15000 kbps)
  - ⚠️ Actual bitrate may be lower than target (VideoToolbox dynamically adjusts based on content complexity to optimize efficiency)
- Smart decision: preserve original file if compressed version is larger

#### Audio Compression

- Support MP3/M4A/AAC/WAV/FLAC/OGG input
- Multiple output format options:
  - **Original**: preserve input file format (default)
  - MP3 (libmp3lame)
  - AAC
  - M4A
  - OPUS
  - FLAC (lossless)
  - WAV (uncompressed)
- 8 bitrate options (32-320 kbps)
  - 32 kbps - Very low quality
  - 64 kbps - Voice/Podcast (mono)
  - 96 kbps - Low quality music
  - 128 kbps - Standard MP3 quality (default)
  - 160 kbps - Good music quality
  - 192 kbps - Very good quality
  - 256 kbps - High quality music
  - 320 kbps - Maximum MP3 quality
- 7 sample rate options (8-48 kHz)
  - 8 kHz - Telephone quality
  - 11.025 kHz - AM radio
  - 16 kHz - Wideband voice
  - 22.05 kHz - FM radio
  - 32 kHz - Digital broadcast
  - 44.1 kHz - CD standard (default)
  - 48 kHz - Professional audio
- Channel selection (mono/stereo)
- Smart quality protection: prevent low-quality audio from being "upscaled"
- Smart decision: preserve original file if compressed version is larger

### 2. Resolution Adjustment

- Batch adjust image and video resolution
- Preset multiple common sizes (4K wallpaper, phone wallpaper, social media, etc.)
- Support custom resolution
- Smart cropping and scaling, maintaining image integrity

### 3. Format Conversion

- Batch convert image formats: JPEG ↔ PNG ↔ WebP ↔ HEIC ↔ AVIF
- Batch convert video formats: MP4 ↔ MOV ↔ M4V
- Batch convert audio formats: MP3 ↔ M4A ↔ AAC ↔ FLAC ↔ WAV ↔ OGG
- Lossless conversion (where possible), maintaining original quality
- No compression, only format modification

## Contact

For questions or suggestions, please contact: <stormte@gmail.com>
