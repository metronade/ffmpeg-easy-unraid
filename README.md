# FFmpeg-Easy-Unraid

<img src="./icon.png" width="150" height="150">

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

## ⚖️ CPU vs. GPU Encoding: What should I choose?

* **Choose CPU Encoding (`cpu_h265`)** if you want the **best possible compression efficiency and quality preservation**. CPU encoders (libx265) are generally smarter than GPU encoders, resulting in smaller files for the same visual quality. Ideally, use this for long-term archiving.
* **Choose GPU Encoding (`nvidia_...` / `intel_...`)** if **speed** is your priority. GPUs can process files much faster, but the file size might be slightly larger to achieve the same visual quality compared to CPU encoding.

---

## ⚙️ Prerequisites

Before installing, ensure your system meets the requirements for your desired encoding method:

### 1. For Nvidia GPU Encoding
* **Unraid Plugin:** You must install the **"Nvidia Driver"** plugin from Community Applications.
* **AV1 Support:** Requires a modern GPU (e.g., **RTX 40-series**). Older cards do not support AV1 encoding!
* **Configuration:** You must pass the GPU UUID to the container (or use `NVIDIA_VISIBLE_DEVICES=all`).

### 2. For Intel GPU Encoding (QuickSync / Arc)
* **Device Mapping:** You must pass the device `/dev/dri` to the container.
* **AV1 Support:** Requires an **Intel Arc GPU** or newer iGPU (Meteor Lake+).

### 3. For CPU Encoding
* **Recommendation:** Use **CPU Pinning** in the Unraid Docker settings to assign specific cores. If you forget this, the script's safety mode will engage (limiting to 50% load).

---

## 🚀 Configuration & Environment Variables

The container is controlled via Environment Variables.

### A Note on Defaults
> **Why these default values?**
>
> The default settings (CRF 18 for H.265 / CRF 24 for AV1) are chosen based on extensive personal testing. In my experience, these values represent the **"Sweet Spot"**: they provide significant file size reduction while maintaining visual quality that is virtually indistinguishable from the source.
>
> Unless you have specific needs, I recommend leaving the Quality fields empty to use these smart defaults.

### Variable List

| Variable | Default | Description |
| :--- | :--- | :--- |
| `ENCODE_METHOD` | `cpu_h265` | **The Encoder Engine.**<br>Options: `cpu_h265`, `cpu_av1`, `nvidia_h265`, `nvidia_av1`, `intel_h265`, `intel_av1`. |
| `ENCODE_PRESET` | `default` | **Speed vs. Efficiency.**<br>`default` automatically picks `medium` (CPU) or `p4` (Nvidia).<br>Manual options: `slow`, `fast`, `p1`-`p7` (Nvidia), `0`-`13` (SVT-AV1). |
| `ENCODE_THREADS` | `0` | **CPU Usage.**<br>`0` = Auto-Detect (Checks for pinning).<br>Set a number (e.g., `4`) to force a specific thread count. Only affects CPU encoding. |
| `ENCODE_CRF` | *(Smart)* | **Quality for CPU/Intel.**<br>Lower value = Better Quality, Larger File.<br>Defaults: `18` (H.265), `24` (AV1). |
| `ENCODE_CQ` | *(Smart)* | **Quality for Nvidia.**<br>Lower value = Better Quality, Larger File.<br>Defaults: `19` (H.265), `24` (AV1). |
| `FFMPEG_CUSTOM_ARGS`| *(Empty)* | **Audio/Subtitles Override.**<br>Default behavior is `-c:a copy -c:s copy`.<br>Use this to convert audio, e.g., `-c:a aac -b:a 192k`. |
| `UNRAID_UID` | `99` | User ID for file permissions (Standard Unraid: 99). |
| `UNRAID_GID` | `100` | Group ID for file permissions (Standard Unraid: 100). |

---

## 📂 Folder Structure (Mappings)

You need to map two volumes in Docker/Unraid:

1.  **Input:** Map your source media folder to `/import`.
    * *Note:* The container needs **Read/Write** access to move finished files to `/import/finished`.
2.  **Output:** Map your destination folder to `/export`.

**Example Workflow:**
1.  You place a TV Show folder `MySeries/Season 1/Episode 1.mkv` in `/import`.
2.  Script converts it and saves the new version to `/export/MySeries/Season 1/Episode 1.mkv`.
3.  Script moves the original to `/import/finished/MySeries/Season 1/Episode 1.mkv`.

---

## 📜 License

Distributed under the **MIT License**. See `LICENSE` for more information.

---

**Author:** [metronade](https://github.com/metronade)
