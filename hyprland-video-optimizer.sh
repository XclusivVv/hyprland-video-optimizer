#!/usr/bin/env bash

# Interactive Video Wallpaper Optimizer (H.265/HEVC Edition)
# User-friendly version with guided setup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration variables
TARGET_WIDTH=2560
TARGET_HEIGHT=1440
TARGET_FPS=30
CRF=28
PRESET="p5"
OUTPUT_FORMAT="mp4"
OUTPUT_DIR="./optimized-hevc"
ENCODER="libx265"
HWACCEL_FLAGS=""
GPU_NAME=""
BATCH_MODE=0
INPUT=""
ALLOW_UPSCALE=0
LOW_BITRATE_THRESHOLD=2000000

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v ffmpeg &> /dev/null; then
        missing+=("ffmpeg")
    fi
    if ! command -v ffprobe &> /dev/null; then
        missing+=("ffprobe")
    fi
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required tools: ${missing[*]}${NC}"
        echo "Install with: sudo pacman -S ${missing[*]}"
        exit 1
    fi
}

# Print header
print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}     ${MAGENTA}Interactive Video Wallpaper Optimizer (H.265)${NC}      ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Prompt with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local response
    
    read -r -p "${prompt} [${default}]: " response
    echo "${response:-$default}"
}

# Yes/No prompt
prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local response
    
    if [ "$default" == "y" ]; then
        echo -ne "${GREEN}${prompt}${NC} ${YELLOW}[Y/n]${NC}: "
    else
        echo -ne "${GREEN}${prompt}${NC} ${YELLOW}[y/N]${NC}: "
    fi
    
    read -r response
    response="${response:-$default}"
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Detect monitor resolution using hyprctl
detect_monitor_resolution() {
    if ! command -v hyprctl &> /dev/null; then
        echo ""
        return 1
    fi
    
    local monitors_output
    monitors_output=$(hyprctl monitors 2>/dev/null || echo "")
    
    if [ -z "$monitors_output" ]; then
        return 1
    fi
    
    # Extract first resolution (format: 2560x1440@144.99800)
    local resolution
    resolution=$(echo "$monitors_output" | grep -oP '\d+x\d+@' | head -n1 | sed 's/@$//')
    
    if [ -n "$resolution" ]; then
        echo "$resolution"
        return 0
    fi
    
    return 1
}

# Setup resolution
setup_resolution() {
    echo ""
    echo -e "${BLUE}═══ Resolution Setup ═══${NC}"
    echo ""
    
    local auto_res
    auto_res=$(detect_monitor_resolution)
    
    if [ -n "$auto_res" ]; then
        echo -e "${GREEN}✓ Detected monitor resolution: ${YELLOW}${auto_res}${NC}"
        echo ""
        if prompt_yes_no "Use detected resolution?" "y"; then
            IFS='x' read -r TARGET_WIDTH TARGET_HEIGHT <<< "$auto_res"
            echo -e "${GREEN}✓ Using ${TARGET_WIDTH}x${TARGET_HEIGHT}${NC}"
            return
        fi
    fi
    
    echo ""
    echo -e "${CYAN}Common resolutions:${NC}"
    echo "  1) 3840x2160 (4K)"
    echo "  2) 2560x1440 (1440p)"
    echo "  3) 1920x1080 (1080p)"
    echo "  4) Custom resolution"
    echo ""
    
    local choice
    choice=$(prompt_with_default "Select resolution" "2")
    
    case $choice in
        1)
            TARGET_WIDTH=3840
            TARGET_HEIGHT=2160
            ;;
        2)
            TARGET_WIDTH=2560
            TARGET_HEIGHT=1440
            ;;
        3)
            TARGET_WIDTH=1920
            TARGET_HEIGHT=1080
            ;;
        4)
            TARGET_WIDTH=$(prompt_with_default "Enter width" "2560")
            TARGET_HEIGHT=$(prompt_with_default "Enter height" "1440")
            ;;
        *)
            TARGET_WIDTH=2560
            TARGET_HEIGHT=1440
            ;;
    esac
    
    echo -e "${GREEN}✓ Target resolution: ${TARGET_WIDTH}x${TARGET_HEIGHT}${NC}"
}

# Setup scaling behavior
setup_scaling() {
    echo ""
    echo -e "${BLUE}═══ Scaling Behavior ═══${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} Videos smaller than target resolution can be:"
    echo "  • Kept at original size (recommended - saves space)"
    echo "  • Upscaled to target resolution (may reduce quality)"
    echo ""
    
    if prompt_yes_no "Allow upscaling of smaller videos?" "n"; then
        ALLOW_UPSCALE=1
        echo -e "${GREEN}✓ Will upscale smaller videos${NC}"
    else
        ALLOW_UPSCALE=0
        echo -e "${GREEN}✓ Will keep original size for smaller videos${NC}"
    fi
}

# Setup FPS
setup_fps() {
    echo ""
    echo -e "${BLUE}═══ Frame Rate (FPS) ═══${NC}"
    echo ""
    echo -e "${CYAN}Common frame rates:${NC}"
    echo "  1) 30 FPS  (Standard, smaller files)"
    echo "  2) 60 FPS  (Smooth, larger files)"
    echo "  3) 24 FPS  (Cinematic, smallest files)"
    echo "  4) Custom"
    echo ""
    
    local choice
    choice=$(prompt_with_default "Select frame rate" "1")
    
    case $choice in
        1) TARGET_FPS=30 ;;
        2) TARGET_FPS=60 ;;
        3) TARGET_FPS=24 ;;
        4) TARGET_FPS=$(prompt_with_default "Enter FPS" "30") ;;
        *) TARGET_FPS=30 ;;
    esac
    
    echo -e "${GREEN}✓ Target FPS: ${TARGET_FPS}${NC}"
}

# Setup quality
setup_quality() {
    echo ""
    echo -e "${BLUE}═══ Encoding Quality ═══${NC}"
    echo ""
    echo -e "${YELLOW}Higher quality = larger files | Lower quality = smaller files${NC}"
    echo ""
    echo -e "${CYAN}Quality presets:${NC}"
    echo "  1) Maximum Quality  (Larger files, nearly lossless)"
    echo "  2) High Quality     (Good balance, recommended)"
    echo "  3) Medium Quality   (Smaller files, visible compression)"
    echo "  4) Low Quality      (Smallest files, noticeable quality loss)"
    echo "  5) Custom value     (For advanced users)"
    echo ""
    
    local choice
    choice=$(prompt_with_default "Select quality level" "2")
    
    case $choice in
        1)
            CRF=23
            echo -e "${GREEN}✓ Maximum Quality (CRF 23)${NC}"
            ;;
        2)
            CRF=28
            echo -e "${GREEN}✓ High Quality (CRF 28) - Recommended${NC}"
            ;;
        3)
            CRF=32
            echo -e "${GREEN}✓ Medium Quality (CRF 32)${NC}"
            ;;
        4)
            CRF=36
            echo -e "${GREEN}✓ Low Quality (CRF 36)${NC}"
            ;;
        5)
            echo ""
            echo -e "${YELLOW}CRF range: 0-51 (lower = better quality, 23-32 recommended)${NC}"
            CRF=$(prompt_with_default "Enter CRF value" "28")
            echo -e "${GREEN}✓ Custom Quality (CRF ${CRF})${NC}"
            ;;
        *)
            CRF=28
            echo -e "${GREEN}✓ High Quality (CRF 28)${NC}"
            ;;
    esac
}

# Setup encoding speed
setup_preset() {
    echo ""
    echo -e "${BLUE}═══ Encoding Speed ═══${NC}"
    echo ""
    
    if [ "$ENCODER" == "hevc_nvenc" ]; then
        echo -e "${CYAN}GPU (NVENC) presets:${NC}"
        echo "  1) Fastest      (Quick encoding, larger files)"
        echo "  2) Fast         (Good speed, decent compression)"
        echo "  3) Balanced     (Recommended for most users)"
        echo "  4) Quality      (Slower, better compression)"
        echo "  5) Maximum      (Slowest, best compression)"
        echo ""
        
        local choice
        choice=$(prompt_with_default "Select encoding speed" "3")
        
        case $choice in
            1) PRESET="p1" ;;
            2) PRESET="p3" ;;
            3) PRESET="p5" ;;
            4) PRESET="p6" ;;
            5) PRESET="p7" ;;
            *) PRESET="p5" ;;
        esac
    else
        echo -e "${CYAN}CPU (libx265) presets:${NC}"
        echo "  1) Ultrafast  (Fastest, largest files)"
        echo "  2) Superfast  (Very fast, larger files)"
        echo "  3) Fast       (Quick, reasonable size)"
        echo "  4) Medium     (Balanced - recommended)"
        echo "  5) Slow       (Better compression, takes longer)"
        echo ""
        
        local choice
        choice=$(prompt_with_default "Select encoding speed" "4")
        
        case $choice in
            1) PRESET="ultrafast" ;;
            2) PRESET="superfast" ;;
            3) PRESET="fast" ;;
            4) PRESET="medium" ;;
            5) PRESET="slow" ;;
            *) PRESET="medium" ;;
        esac
    fi
    
    echo -e "${GREEN}✓ Preset: ${PRESET}${NC}"
}

# Setup hardware acceleration
setup_hardware_acceleration() {
    echo ""
    echo -e "${BLUE}═══ Hardware Acceleration ═══${NC}"
    echo ""
    
    local has_nvidia=0
    local has_amd=0
    
    # Check for NVIDIA
    if command -v nvidia-smi &> /dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)
        if [ -n "$GPU_NAME" ]; then
            has_nvidia=1
            echo -e "${GREEN}✓ NVIDIA GPU detected: ${GPU_NAME}${NC}"
        fi
    fi
    
    # Check for AMD
    if command -v rocm-smi &> /dev/null || [ -d /sys/class/drm/card0/device/driver/amdgpu ] || lspci 2>/dev/null | grep -qi "amd.*vga\|amd.*display"; then
        has_amd=1
        echo -e "${GREEN}✓ AMD GPU detected${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Available options:${NC}"
    
    local options=()
    local option_num=1
    
    if [ $has_nvidia -eq 1 ]; then
        echo "  ${option_num}) NVIDIA GPU (Fastest, recommended)"
        options+=("nvidia")
        ((option_num++))
    fi
    
    if [ $has_amd -eq 1 ]; then
        echo "  ${option_num}) AMD GPU (Fast)"
        options+=("amd")
        ((option_num++))
    fi
    
    echo "  ${option_num}) CPU (Slowest, works everywhere)"
    options+=("cpu")
    
    echo ""
    
    local choice
    if [ ${#options[@]} -eq 1 ]; then
        choice=1
        echo -e "${YELLOW}Only CPU encoding available${NC}"
    else
        read -r -p "$(echo -e "${GREEN}Select hardware acceleration${NC} ${YELLOW}[1]${NC}: ")" choice
        choice=${choice:-1}
    fi
    
    # Validate choice is a number
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        choice=1
    fi
    
    local selected_option="${options[$((choice-1))]}"
    
    case $selected_option in
        nvidia)
            if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_nvenc"; then
                ENCODER="hevc_nvenc"
                HWACCEL_FLAGS="-hwaccel cuda -hwaccel_output_format cuda"
                echo -e "${GREEN}✓ Using NVIDIA GPU encoding (HEVC_NVENC)${NC}"
            else
                echo -e "${RED}Error: NVIDIA GPU found but HEVC_NVENC not available in ffmpeg${NC}"
                ENCODER="libx265"
                echo -e "${YELLOW}Falling back to CPU encoding${NC}"
            fi
            ;;
        amd)
            if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_amf"; then
                ENCODER="hevc_amf"
                HWACCEL_FLAGS="-hwaccel auto"
                echo -e "${GREEN}✓ Using AMD GPU encoding (HEVC_AMF)${NC}"
            elif ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_vaapi"; then
                ENCODER="hevc_vaapi"
                HWACCEL_FLAGS="-hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi"
                echo -e "${GREEN}✓ Using AMD GPU encoding (HEVC_VAAPI)${NC}"
            else
                echo -e "${RED}Error: AMD GPU found but no compatible HEVC encoder available${NC}"
                ENCODER="libx265"
                echo -e "${YELLOW}Falling back to CPU encoding${NC}"
            fi
            ;;
        cpu|*)
            ENCODER="libx265"
            HWACCEL_FLAGS=""
            echo -e "${GREEN}✓ Using CPU encoding (libx265)${NC}"
            echo -e "${YELLOW}  Note: This will be slower than GPU encoding${NC}"
            ;;
    esac
}

# Setup output format
setup_output_format() {
    echo ""
    echo -e "${BLUE}═══ Output Format ═══${NC}"
    echo ""
    echo -e "${CYAN}Container formats:${NC}"
    echo "  1) MP4  (Most compatible, recommended)"
    echo "  2) MKV  (Flexible, good for archiving)"
    echo ""
    
    local choice
    choice=$(prompt_with_default "Select format" "1")
    
    case $choice in
        1) OUTPUT_FORMAT="mp4" ;;
        2) OUTPUT_FORMAT="mkv" ;;
        *) OUTPUT_FORMAT="mp4" ;;
    esac
    
    echo -e "${GREEN}✓ Output format: ${OUTPUT_FORMAT}${NC}"
}

# Setup output directory
setup_output_directory() {
    echo ""
    echo -e "${BLUE}═══ Output Directory ═══${NC}"
    echo ""
    
    local output_path
    read -r -p "$(echo -e "${GREEN}")Output directory$(echo -e "${NC} ${YELLOW}")[./optimized-hevc]$(echo -e "${NC}"): " output_path
    OUTPUT_DIR="${output_path:-./optimized-hevc}"
    
    # Expand ~ to home directory
    OUTPUT_DIR="${OUTPUT_DIR/#\~/$HOME}"
    
    echo -e "${GREEN}✓ Output directory: ${OUTPUT_DIR}${NC}"
}

# Setup input
setup_input() {
    echo ""
    echo -e "${BLUE}═══ Input Selection ═══${NC}"
    echo ""
    
    if prompt_yes_no "Process multiple files (batch mode)?" "y"; then
        BATCH_MODE=1
        echo ""
        
        local input_path
        while true; do
            read -r -p "$(echo -e "${GREEN}")Enter directory path$(echo -e "${NC} ${YELLOW}")[.]$(echo -e "${NC}"): " input_path
            INPUT="${input_path:-.}"
            INPUT="${INPUT/#\~/$HOME}"
            
            if [ -d "$INPUT" ]; then
                break
            else
                echo -e "${RED}Error: Directory not found: $INPUT${NC}"
                echo -e "${YELLOW}Please enter a valid directory path${NC}"
            fi
        done
        
        echo -e "${GREEN}✓ Batch mode: Processing all videos in ${INPUT}${NC}"
    else
        BATCH_MODE=0
        echo ""
        
        local input_path
        while true; do
            read -r -p "$(echo -e "${GREEN}")Enter video file path$(echo -e "${NC}"): " input_path
            INPUT="${input_path}"
            INPUT="${INPUT/#\~/$HOME}"
            
            if [ -f "$INPUT" ]; then
                break
            else
                echo -e "${RED}Error: File not found: $INPUT${NC}"
                echo -e "${YELLOW}Please enter a valid file path${NC}"
            fi
        done
        
        echo -e "${GREEN}✓ Single file mode: ${INPUT}${NC}"
    fi
}

# Display configuration summary
show_summary() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                   ${MAGENTA}Configuration Summary${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Resolution:${NC}      ${TARGET_WIDTH}x${TARGET_HEIGHT}"
    echo -e "${YELLOW}Frame Rate:${NC}      ${TARGET_FPS} FPS"
    echo -e "${YELLOW}Quality:${NC}         CRF ${CRF}"
    echo -e "${YELLOW}Encoder:${NC}         ${ENCODER}"
    echo -e "${YELLOW}Preset:${NC}          ${PRESET}"
    echo -e "${YELLOW}Format:${NC}          ${OUTPUT_FORMAT}"
    echo -e "${YELLOW}Upscaling:${NC}       $([ $ALLOW_UPSCALE -eq 1 ] && echo "Enabled" || echo "Disabled")"
    echo -e "${YELLOW}Output Dir:${NC}      ${OUTPUT_DIR}"
    echo -e "${YELLOW}Mode:${NC}            $([ $BATCH_MODE -eq 1 ] && echo "Batch" || echo "Single file")"
    echo -e "${YELLOW}Input:${NC}           ${INPUT}"
    echo ""
}

# Get video info
get_video_info() {
    local file="$1"
    ffprobe -v quiet -print_format json -show_format -show_streams "$file"
}

# Optimize a single video
optimize_video() {
    local input_file="$1"
    local current_num="$2"
    local total_num="$3"
    local filename=$(basename "$input_file")
    local name="${filename%.*}"
    local output_file="${OUTPUT_DIR}/${name}_optimized.${OUTPUT_FORMAT}"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ -n "$current_num" ] && [ -n "$total_num" ]; then
        echo -e "${CYAN}[${current_num}/${total_num}]${NC} ${GREEN}Processing:${NC} $filename"
    else
        echo -e "${GREEN}Processing:${NC} $filename"
    fi
    
    # Get original file info
    local original_size=$(du -h "$input_file" | cut -f1)
    echo -e "${YELLOW}Original size:${NC} $original_size"
    
    local video_info
    video_info=$(get_video_info "$input_file")
    
    local v_stream=$(echo "$video_info" | jq '.streams[] | select(.codec_type=="video")')
    local width=$(echo "$v_stream" | jq -r '.width')
    local height=$(echo "$v_stream" | jq -r '.height')
    local codec_name=$(echo "$v_stream" | jq -r '.codec_name')
    local bit_rate=$(echo "$video_info" | jq -r '.format.bit_rate')
    
    if [ "$bit_rate" == "null" ]; then
        bit_rate=0
    fi
    
    echo -e "${YELLOW}Original resolution:${NC} ${width}x${height} (${codec_name})"

    # Smart skip logic
    if [ "$codec_name" == "hevc" ] && [ "$bit_rate" -lt "$LOW_BITRATE_THRESHOLD" ] && [ "$height" -le "$TARGET_HEIGHT" ]; then
        echo -e "${GREEN}✓ Skipping re-encode:${NC} Already efficient HEVC"
        echo -e "${CYAN}Copying video stream...${NC}"
        ffmpeg -hide_banner -i "$input_file" -c:v copy -an -y "$output_file" 2>/dev/null || true
    else
        # Scaling logic
        local VF_FILTER_CHAIN=""
        
        if [ "$height" -gt "$TARGET_HEIGHT" ]; then
            # Downscaling
            echo -e "${YELLOW}Downscaling from ${height}p to ${TARGET_HEIGHT}p${NC}"
            case $ENCODER in
                hevc_nvenc)
                    VF_FILTER_CHAIN="scale_cuda=${TARGET_WIDTH}:${TARGET_HEIGHT}:force_original_aspect_ratio=increase,crop=${TARGET_WIDTH}:${TARGET_HEIGHT}"
                    ;;
                hevc_vaapi)
                    VF_FILTER_CHAIN="scale_vaapi=w=${TARGET_WIDTH}:h=${TARGET_HEIGHT}:force_original_aspect_ratio=increase,crop=${TARGET_WIDTH}:${TARGET_HEIGHT}"
                    ;;
                *)
                    VF_FILTER_CHAIN="scale=${TARGET_WIDTH}:${TARGET_HEIGHT}:force_original_aspect_ratio=increase,crop=${TARGET_WIDTH}:${TARGET_HEIGHT}"
                    ;;
            esac
        elif [ "$height" -lt "$TARGET_HEIGHT" ] && [ $ALLOW_UPSCALE -eq 1 ]; then
            # Upscaling
            echo -e "${YELLOW}Upscaling from ${height}p to ${TARGET_HEIGHT}p${NC}"
            case $ENCODER in
                hevc_nvenc)
                    VF_FILTER_CHAIN="scale_cuda=${TARGET_WIDTH}:${TARGET_HEIGHT}:force_original_aspect_ratio=increase,crop=${TARGET_WIDTH}:${TARGET_HEIGHT}"
                    ;;
                hevc_vaapi)
                    VF_FILTER_CHAIN="scale_vaapi=w=${TARGET_WIDTH}:h=${TARGET_HEIGHT}:force_original_aspect_ratio=increase,crop=${TARGET_WIDTH}:${TARGET_HEIGHT}"
                    ;;
                *)
                    VF_FILTER_CHAIN="scale=${TARGET_WIDTH}:${TARGET_HEIGHT}:force_original_aspect_ratio=increase,crop=${TARGET_WIDTH}:${TARGET_HEIGHT}"
                    ;;
            esac
        else
            # Keep original resolution
            echo -e "${YELLOW}Keeping original resolution ${width}x${height}${NC}"
            case $ENCODER in
                hevc_nvenc)
                    VF_FILTER_CHAIN="scale_cuda=${width}:${height}"
                    ;;
                hevc_vaapi)
                    VF_FILTER_CHAIN="scale_vaapi=w=${width}:h=${height}"
                    ;;
                *)
                    VF_FILTER_CHAIN="scale=${width}:${height}"
                    ;;
            esac
        fi
        
        # Quality flags
        local QUALITY_FLAGS=""
        case $ENCODER in
            hevc_nvenc)
                QUALITY_FLAGS="-cq $CRF -rc vbr"
                ;;
            hevc_amf)
                QUALITY_FLAGS="-qp $CRF -rc cqp"
                ;;
            hevc_vaapi)
                QUALITY_FLAGS="-qp $CRF"
                ;;
            *)
                QUALITY_FLAGS="-crf $CRF"
                ;;
        esac

        echo -e "${GREEN}Encoding...${NC}"
        echo -e "${CYAN}Progress:${NC}"
        
        ffmpeg -hide_banner \
            $HWACCEL_FLAGS \
            -i "$input_file" \
            -vf "$VF_FILTER_CHAIN" \
            -c:v "$ENCODER" \
            -preset "$PRESET" \
            $QUALITY_FLAGS \
            -r "$TARGET_FPS" \
            -an \
            -movflags +faststart \
            -y \
            -progress pipe:1 \
            "$output_file" 2>&1 | while IFS= read -r line; do
                if [[ "$line" =~ ^frame= ]]; then
                    echo -ne "\r${CYAN}  $line${NC}"
                elif [[ "$line" =~ ^out_time_ms= ]]; then
                    :
                elif [[ "$line" =~ ^progress= ]]; then
                    if [[ "$line" == "progress=end" ]]; then
                        echo ""
                    fi
                fi
            done
    fi
    
    if [ -f "$output_file" ]; then
        local new_size=$(du -h "$output_file" | cut -f1)
        local orig_s_bytes=$(stat -c%s "$input_file")
        local new_s_bytes=$(stat -c%s "$output_file")
        
        if [ "$orig_s_bytes" -eq 0 ]; then
            orig_s_bytes=1
        fi
        
        local reduction=$(echo "scale=1; (1 - $new_s_bytes / $orig_s_bytes) * 100" | bc)
        
        echo -e "${GREEN}✓ Complete!${NC}"
        echo -e "${YELLOW}New size:${NC} $new_size"
        if (( $(echo "$reduction > 0" | bc -l) )); then
            echo -e "${GREEN}Size reduction: ${reduction}%${NC}"
        else
            echo -e "${RED}Size increase: ${reduction}%${NC}"
        fi
        echo -e "${YELLOW}Saved to:${NC} $output_file"
    else
        echo -e "${RED}✗ Failed to process $filename${NC}"
    fi
    
    echo ""
}

# Main execution
main() {
    print_header
    check_dependencies
    
    echo -e "${YELLOW}This wizard will guide you through optimizing videos for wallpapers.${NC}"
    echo -e "${YELLOW}Press Enter to accept default values shown in [brackets].${NC}"
    
    setup_hardware_acceleration
    setup_resolution
    setup_scaling
    setup_fps
    setup_quality
    setup_preset
    setup_output_format
    setup_output_directory
    setup_input
    
    show_summary
    
    if ! prompt_yes_no "Start processing with these settings?" "y"; then
        echo -e "${YELLOW}Cancelled by user${NC}"
        exit 0
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${MAGENTA}Starting Processing${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ $BATCH_MODE -eq 1 ]; then
        shopt -s nullglob
        videos=("$INPUT"/*.{mp4,mkv,avi,mov,webm,flv,wmv,m4v})
        shopt -u nullglob
        
        if [ ${#videos[@]} -eq 0 ]; then
            echo -e "${RED}No video files found in $INPUT${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}Found ${#videos[@]} video(s)${NC}"
        echo ""
        
        local count=1
        for video in "${videos[@]}"; do
            optimize_video "$video" "$count" "${#videos[@]}"
            ((count++))
        done
    else
        optimize_video "$INPUT"
    fi
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}All done! Optimized videos are in: ${OUTPUT_DIR}${NC}"
    echo ""
}

# Run main function
main