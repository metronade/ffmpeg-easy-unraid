#!/bin/bash
# ==============================================================================
# Script: FFmpeg-Easy-Unraid (v5.3 - UX Update)
# Author: metronade
# ==============================================================================

shopt -s nullglob

# --- GLOBAL VARS ---
METHOD="${ENCODE_METHOD:-cpu_h265}"
THREADS_INPUT="${ENCODE_THREADS:-0}"
PRESET_INPUT="${ENCODE_PRESET:-default}"
CUSTOM_ARGS="${FFMPEG_CUSTOM_ARGS:-}"

TARGET_UID="${UNRAID_UID:-99}"
TARGET_GID="${UNRAID_GID:-100}"

SOURCE_DIR="/import"
EXPORT_DIR="/export"
FINISHED_DIR="$SOURCE_DIR/finished"
LOG_FILE="$EXPORT_DIR/history.log"

CRF_VALUE=""
CQ_VALUE=""
PRESET=""
FINAL_THREADS=0
START_TIME=$SECONDS
SIZE_IN_TOTAL=0
SIZE_OUT_TOTAL=0

# ==============================================================================
# FUNCTIONS
# ==============================================================================

configure_settings() {
    # A) Smart Defaults: CRF/CQ
    if [ -z "$ENCODE_CRF" ] && [ -z "$ENCODE_CQ" ]; then
        if [[ "$METHOD" == *"av1"* ]]; then
            CRF_VALUE=24; CQ_VALUE=24
        else
            CRF_VALUE=18; CQ_VALUE=19
        fi
    else
        CRF_VALUE="${ENCODE_CRF:-18}"
        CQ_VALUE="${ENCODE_CQ:-19}"
    fi

    # B) Smart Defaults: Preset
    if [ "$PRESET_INPUT" == "default" ]; then
        if [[ "$METHOD" == *"nvidia"* ]]; then PRESET="p4";
        elif [[ "$METHOD" == *"cpu_av1"* ]]; then PRESET="8";
        else PRESET="medium"; fi
    else
        PRESET="$PRESET_INPUT"
    fi

    # C) CPU Safety Logic
    if [ "$THREADS_INPUT" -eq 0 ] && [[ "$METHOD" == *"cpu"* ]]; then
        local host_cores=$(nproc --all)
        local container_cores=$(nproc)
        if [ "$container_cores" -lt "$host_cores" ]; then
            echo "[INIT] CPU Pinning detected ($container_cores cores). Using max performance."
            FINAL_THREADS=0
        else
            local safe_limit=$((host_cores / 2))
            [ "$safe_limit" -lt 1 ] && safe_limit=1
            echo "[INIT] NO Pinning detected. SAFETY MODE: Limiting to $safe_limit threads (50%)."
            FINAL_THREADS=$safe_limit
        fi
    else
        FINAL_THREADS="$THREADS_INPUT"
    fi
}

check_paths() {
    echo "[INIT] Method: $METHOD | Preset: $PRESET | CRF/CQ: $CRF_VALUE/$CQ_VALUE"
    if [ ! -d "$SOURCE_DIR" ]; then echo "[FATAL] /import missing."; exit 1; fi

    local r_src; r_src=$(realpath "$SOURCE_DIR")
    local r_exp; r_exp=$(realpath "$EXPORT_DIR")

    if [ "$r_src" == "$r_exp" ]; then echo "[FATAL] Input/Output paths identical."; exit 1; fi
    if [[ "$r_exp" == "$r_src"* ]]; then echo "[FATAL] Output is subdirectory of Input."; exit 1; fi
    
    mkdir -p "$EXPORT_DIR"
    mkdir -p "$FINISHED_DIR"
    chown "$TARGET_UID":"$TARGET_GID" "$FINISHED_DIR"
    touch "$LOG_FILE"
}

check_hardware() {
    local test_cmd=""
    # Suppress verbose hardware check errors to keep log clean
    case "$METHOD" in
        "nvidia_"*) test_cmd="ffmpeg -y -f lavfi -i color=c=black:s=64x64 -vframes 1 -c:v hevc_nvenc -f null -" ;;
        "intel_"*)  test_cmd="ffmpeg -y -hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device /dev/dri/renderD128 -f lavfi -i color=c=black:s=64x64 -vframes 1 -c:v hevc_vaapi -f null -" ;;
        *)          test_cmd="true" ;;
    esac

    if ! $test_cmd > /dev/null 2>&1; then
        echo "[FATAL] Hardware check failed for '$METHOD'. Check GPU/Drivers/Permissions."
        exit 1
    fi
}

get_ffmpeg_cmd() {
    local input="$1"; local output="$2"
    # Added -hide_banner and -loglevel error to reduce spam, but kept -stats for progress
    local cmd_prefix=(nice -n 19 ffmpeg -hide_banner -loglevel error -stats -y)
    local audio_sub_args="${CUSTOM_ARGS:--c:a copy -c:s copy}"

    case "$METHOD" in
        "nvidia_av1")  echo "${cmd_prefix[@]} -hwaccel cuda -hwaccel_output_format cuda -i \"$input\" -map 0 -c:v av1_nvenc -cq $CQ_VALUE -preset $PRESET $audio_sub_args \"$output\"" ;;
        "nvidia_h265") echo "${cmd_prefix[@]} -hwaccel cuda -hwaccel_output_format cuda -i \"$input\" -map 0 -c:v hevc_nvenc -cq $CQ_VALUE -preset $PRESET $audio_sub_args \"$output\"" ;;
        "intel_av1")   echo "${cmd_prefix[@]} -hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device /dev/dri/renderD128 -i \"$input\" -map 0 -c:v av1_qsv -global_quality $CRF_VALUE -preset $PRESET $audio_sub_args \"$output\"" ;;
        "intel_h265")  echo "${cmd_prefix[@]} -hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device /dev/dri/renderD128 -i \"$input\" -map 0 -c:v hevc_vaapi -vf 'format=nv12,hwupload' -qp $CRF_VALUE $audio_sub_args \"$output\"" ;;
        "cpu_av1")     echo "${cmd_prefix[@]} -i \"$input\" -threads $FINAL_THREADS -map 0 -c:v libsvtav1 -crf $CRF_VALUE -preset $PRESET $audio_sub_args \"$output\"" ;;
        *)             echo "${cmd_prefix[@]} -i \"$input\" -threads $FINAL_THREADS -map 0 -c:v libx265 -crf $CRF_VALUE -preset $PRESET $audio_sub_args \"$output\"" ;;
    esac
}

format_bytes_dual() {
    local bytes=$1
    if [ -z "$bytes" ] || [ "$bytes" -eq 0 ]; then echo "0.00 GB | 0.00 MB"; return; fi
    local gb=$(echo "scale=2; $bytes/1073741824" | bc)
    local mb=$(echo "scale=2; $bytes/1048576" | bc)
    echo "${gb} GB | ${mb} MB"
}

# ==============================================================================
# MAIN
# ==============================================================================

configure_settings
check_paths
check_hardware

echo "--------------------------------------------------------"
echo "[INFO] Scanning '/import' for video files... Please wait."
echo "       (Large libraries might take a moment)"

# 1. Load files into an array to count them first
FILES=()
while IFS= read -r -d '' file; do
    FILES+=("$file")
done < <(find "$SOURCE_DIR" -path "$FINISHED_DIR" -prune -o -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.ts" -o -iname "*.m2ts" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.wmv" \) -print0)

TOTAL_FILES=${#FILES[@]}

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "[INFO] No files found to process. Exiting."
    exit 0
fi

echo "[INFO] Found $TOTAL_FILES files to process."
echo "--------------------------------------------------------"

COUNT_SUCCESS=0; COUNT_FAILED=0
CURRENT_INDEX=0

# 2. Process the array
for input_file in "${FILES[@]}"; do
    ((CURRENT_INDEX++))
    
    rel_path="${input_file#$SOURCE_DIR/}"
    fname_no_ext="$(basename -- "$input_file" | sed 's/\.[^.]*$//')"
    rel_dir=$(dirname "$rel_path")
    
    out_file="$EXPORT_DIR/$rel_dir/$fname_no_ext.mkv"
    finish_dest="$FINISHED_DIR/$rel_path"

    echo ""
    echo "[PROGRESS] File $CURRENT_INDEX of $TOTAL_FILES"
    echo "[START] Processing: $fname_no_ext"
    
    mkdir -p "$(dirname "$out_file")"
    chown "$TARGET_UID":"$TARGET_GID" "$(dirname "$out_file")"
    [ -f "$out_file" ] && rm "$out_file"

    current_in_size=$(stat -c%s "$input_file")
    
    # Generate Command
    CMD_STR=$(get_ffmpeg_cmd "$input_file" "$out_file")
    
    # Execute (Filter stderr if needed, but usually --cap-add fixes the noise)
    eval "$CMD_STR"

    if [ $? -eq 0 ]; then
        echo "[DONE] Encoding success."
        echo "DONE: $rel_path" >> "$LOG_FILE"
        current_out_size=$(stat -c%s "$out_file")
        SIZE_IN_TOTAL=$(echo "$SIZE_IN_TOTAL + $current_in_size" | bc)
        SIZE_OUT_TOTAL=$(echo "$SIZE_OUT_TOTAL + $current_out_size" | bc)
        chown "$TARGET_UID":"$TARGET_GID" "$out_file"
        chmod 666 "$out_file"
        
        echo "[MOVE] Moving source to finished directory..."
        mkdir -p "$(dirname "$finish_dest")"
        chown "$TARGET_UID":"$TARGET_GID" "$(dirname "$finish_dest")"
        mv "$input_file" "$finish_dest"
        ((COUNT_SUCCESS++))
    else
        echo "[FAIL] Error processing $rel_path"
        [ -f "$out_file" ] && rm "$out_file"
        ((COUNT_FAILED++))
    fi
done

# STATS
DURATION=$((SECONDS - START_TIME))
H=$((DURATION/3600)); M=$(( (DURATION%3600)/60 )); S=$((DURATION%60))

echo ""
echo "========================================================"
echo " FINAL STATISTICS"
echo "========================================================"
echo " Processed:  $COUNT_SUCCESS (Failed: $COUNT_FAILED)"
echo " Runtime:    ${H}h ${M}m ${S}s"
if [ $COUNT_SUCCESS -gt 0 ]; then
    TXT_IN=$(format_bytes_dual $SIZE_IN_TOTAL)
    TXT_OUT=$(format_bytes_dual $SIZE_OUT_TOTAL)
    TXT_DIFF=$(format_bytes_dual $(echo "$SIZE_IN_TOTAL - $SIZE_OUT_TOTAL" | bc))
    PERCENT=$(awk "BEGIN {printf \"%.2f\", (($SIZE_IN_TOTAL-$SIZE_OUT_TOTAL)/$SIZE_IN_TOTAL)*100}")
    echo " Input:      $TXT_IN"
    echo " Output:     $TXT_OUT"
    echo " Saved:      $TXT_DIFF ($PERCENT%)"
fi
echo "========================================================"
exit 0
