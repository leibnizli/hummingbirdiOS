# Hummingbird - Media Compression Tool

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

## 📋 List Display

Each file item includes:

- 🖼️ Preview thumbnail (80x80)
  - Images: actual preview
  - Videos: first frame
  - Audio: purple-pink gradient background + music note icon
- 📈 Real-time progress bar
- 🎬 Animation indicator (WebP)
  - Blue: original animation (pending)
  - Green: animation preserved successfully
  - Orange: converted to static image
  - Displays frame count information
- 📏 Original file information
  - File size
  - Resolution (images/videos)
  - Duration (videos/audio)
  - Frame rate (videos)
  - Codec (videos)
  - Bitrate (videos/audio)
  - Sample rate (audio)
  - Channels (audio)
- 📉 Compressed file information
  - File size
  - Parameter changes (if any)
  - Bitrate changes (videos/audio, displayed when difference >100 kbps)
- 💰 Space saved
- 📊 Compression ratio percentage
- ✅ Compression status (Loading/Waiting/Compressing/Complete/Failed)

## 🎯 Smart Protection Mechanisms

### Images and Videos

- Automatically preserve original file when compressed version is larger
- Only scale down when original resolution is greater than target
- Only lower frame rate when original is higher than target (frame rate upscaling not supported)
- VideoToolbox hardware encoder dynamically adjusts bitrate based on video content

### Audio (Smart Quality Protection)

- Preserve original bitrate when it's lower than target
  - Example: original 128 kbps + setting 320 kbps = keep 128 kbps
- Preserve original sample rate when it's lower than target
  - Example: original 22.05 kHz + setting 44.1 kHz = keep 22.05 kHz
- Mono won't be converted to stereo
- 0 or unknown values treated as invalid, use target settings
- Prevents fake quality upgrades and file bloat

## Usage

### Compression Feature

1. Click "Add Files" button, select source
   - "Select from Photos" - select from photo library
   - "Select from Files" - select from file manager
2. Select image, video, or audio files (up to 20)
3. Click middle gear icon to adjust compression settings
   - Images: quality, resolution, orientation
   - Videos: codec, bitrate mode (auto/custom), resolution, frame rate
   - Audio: output format, bitrate, sample rate, channels
4. Click "Start" button to begin batch compression
5. View detailed information after compression completes
6. Save files
   - "Photos" - save to photo library (images/videos)
   - "iCloud" - save to iCloud Drive or other locations
   - "Share" - send via system share functionality

### Important Notes

- Audio files cannot be saved to photo library (iOS limitation), use iCloud or Share
- Files cannot be deleted during compression
- Can adjust settings and re-compress at any time
- Audio playback automatically stops when leaving audio-related pages

## Technical Implementation

### Core Technology Stack

- **UI Framework**: SwiftUI
- **Media Processing**: AVFoundation
- **Image Compression**:
  - MozJPEG (JPEG compression)
  - pngquant (libimagequant) + Zopfli (PNG lossy + lossless compression)
  - SDWebImageWebPCoder (WebP compression)
  - SDAnimatedImage (animated WebP support)
- **Video Compression**: FFmpeg (ffmpeg-kit)
  - Hardware-accelerated encoding (VideoToolbox)
  - H.264/H.265 encoders
- **Audio Compression**: FFmpeg (libmp3lame, AAC, OPUS, FLAC)
- **Photo Library Access**: Photos Framework
- **Concurrent Processing**: Swift Concurrency (async/await)
- **State Management**: ObservableObject + @Published
- **Data Persistence**: UserDefaults

### Architecture Design

- **MVVM Pattern**
- **Reactive Programming** (Combine)
- **Asynchronous Processing** (async/await)
- **Modular Design**



## System Requirements

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

## Dependencies

- **ffmpeg-kit-ios-full**: Video and audio processing
- **SDWebImageWebPCoder**: WebP format support (including animated WebP)
- **mozjpeg**: JPEG compression
- **pngquant (libimagequant)**: PNG lossy compression
- **Zopfli**: PNG lossless compression (optional optimization)

## Permissions Required

- Photo library access (read and write)
- File access (read)

## Open Source Licenses

### JPEG Compression Library

Uses mozjpeg - Copyright (c) Mozilla Corporation. All rights reserved.

### PNG Compression Library

Uses pngquant (libimagequant) - GPL v3 or later  
Uses Zopfli - Copyright (c) Google Inc. Apache License 2.0.

## Feature Highlights

### 🎨 Beautiful Interface

- Purple-pink gradient audio thumbnails
- Real-time progress display
- Clear parameter comparison
- Intuitive status indicators

### 🧠 Smart Processing

- Auto-detect media parameters
- Smart quality protection
- Auto-optimize output
- Prevent file bloat

### ⚡ High Performance

- Hardware-accelerated encoding
- Batch concurrent processing
- Optimized memory usage
- Fast compression speed

### 🛡️ Safe and Reliable

- Local processing, no uploads
- Auto cleanup temporary files
- Comprehensive error handling
- Data security protection

## Completed Features

- ✅ Image compression (JPEG/PNG/HEIC/WebP)
- ✅ Animated WebP compression (preserve all frames)
- ✅ Video compression (H.264/H.265)
- ✅ Audio compression (MP3/AAC/M4A/OPUS/FLAC/WAV)
- ✅ Audio format "Original" option (preserve input format)
- ✅ Audio preview playback
- ✅ Audio page auto-stop playback
- ✅ Resolution adjustment
- ✅ Format conversion
- ✅ Batch processing
- ✅ Smart quality protection
- ✅ Real-time progress display
- ✅ Multiple save methods
- ✅ Settings persistence

## Contact

For questions or suggestions, please contact: <stormte@gmail.com>
