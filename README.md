# FFmpeg-Easy-Unraid

<div align="center">
  <img src="./icon.png" width="150" height="150">
</div>

**A "Set and Forget" Batch Transcoder designed for Unraid.** Convert your media library (Movies, TV Series) to modern, space-saving formats (H.265/HEVC or AV1) with ease.

---

## 📖 About The Project

**FFmpeg-Easy-Unraid** is a Docker container built to simplify the process of shrinking large video libraries. It automatically scans an input directory, converts video files to highly efficient formats, and moves the original files to a "finished" folder upon success.

It is designed to be robust ("fail-safe"), supporting modern hardware acceleration while protecting your server from freezing via intelligent CPU monitoring.

### Key Features
* **Modern Codecs:** Supports **H.265 (HEVC)** and **AV1**.
* **Hardware Acceleration:** Full support for **Nvidia NVENC**, **Intel QuickSync/Arc**, and optimized CPU encoding.
* **Smart Workflow:**
    * Scans `/import` for media.
    * Transcodes to `/export`.
    * Moves successfully processed originals to `/import/finished`.
    * **Directory Preservation:** Perfect for TV Shows! Recursively scans folders and recreates the exact directory structure (e.g., `Series Name/Season 1/`) in the output.
* **Safety First:** Detects if CPU pinning is active. If not, it automatically limits thread usage to **50% of available cores** to prevent Unraid from freezing.
* **Detailed Stats:** Displays exact space savings (GB/MB and %) after every run.
* **Container Standardization:** Automatically outputs to **.MKV** for maximum compatibility with subtitles and audio tracks.

---

## 🟢 How to Enable Nvidia Support (Important!)

By default, Docker containers cannot see your Graphics Card. To enable **Nvidia NVENC** support, follow these steps strictly:

### Step 1: Install the Driver
In Unraid, go to the "Apps" tab (Community Applications) and install the **"Nvidia Driver"** plugin. Reboot if asked.

### Step 2: Configure the Container
When adding or editing this container in Unraid:

1. Switch to **"Advanced View"** (toggle in the top right corner).
2. Find the field **"Extra Parameters"**.
3. Add the following text to the end of the line (separated by a space):
   ```text
   --runtime=nvidia
