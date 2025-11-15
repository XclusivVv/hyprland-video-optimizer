#!/usr/bin/env bash

# Hyprland Video Optimizer - Installer
# Installs the video optimizer to ~/.local/bin

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Print header
print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${MAGENTA}Hyprland Video Optimizer Installer${NC}             ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if running on Arch Linux
check_arch() {
    if [ ! -f /etc/arch-release ]; then
        echo -e "${YELLOW}⚠ Warning: This installer is designed for Arch Linux${NC}"
        echo -e "${YELLOW}  Some package names may differ on your distribution${NC}"
        echo ""
    fi
}

# Check and install dependencies
install_dependencies() {
    echo -e "${BLUE}═══ Checking Dependencies ═══${NC}"
    echo ""
    
    local missing_deps=()
    local to_install=()
    
    # Check for each dependency
    if ! command -v ffmpeg &> /dev/null; then
        missing_deps+=("ffmpeg")
        to_install+=("ffmpeg")
    fi
    
    if ! command -v ffprobe &> /dev/null; then
        if [[ ! " ${to_install[@]} " =~ " ffmpeg " ]]; then
            missing_deps+=("ffprobe")
            to_install+=("ffmpeg")
        fi
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
        to_install+=("jq")
    fi
    
    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc")
        to_install+=("bc")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ All dependencies are already installed${NC}"
        echo ""
        return 0
    fi
    
    echo -e "${YELLOW}Missing dependencies: ${missing_deps[*]}${NC}"
    echo ""
    
    # Ask to install
    echo -ne "${GREEN}Install missing dependencies?${NC} ${YELLOW}[Y/n]${NC}: "
    read -r response
    response="${response:-y}"
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}✗ Cannot proceed without dependencies${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${CYAN}Installing: ${to_install[*]}${NC}"
    echo ""
    
    # Install using pacman
    if command -v pacman &> /dev/null; then
        sudo pacman -S --needed --noconfirm "${to_install[@]}"
    else
        echo -e "${RED}Error: pacman not found${NC}"
        echo -e "${YELLOW}Please install manually: ${to_install[*]}${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
    echo ""
}

# Check GPU support
check_gpu_support() {
    echo -e "${BLUE}═══ GPU Support ═══${NC}"
    echo ""
    
    local has_nvidia=0
    local has_amd=0
    
    # Check NVIDIA
    if command -v nvidia-smi &> /dev/null; then
        local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)
        if [ -n "$gpu_name" ]; then
            has_nvidia=1
            echo -e "${GREEN}✓ NVIDIA GPU detected: ${gpu_name}${NC}"
            
            # Check NVENC support
            if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_nvenc"; then
                echo -e "${GREEN}✓ HEVC_NVENC encoder available${NC}"
            else
                echo -e "${YELLOW}⚠ HEVC_NVENC not available in ffmpeg${NC}"
                echo -e "${YELLOW}  Consider rebuilding ffmpeg with NVENC support${NC}"
            fi
        fi
    fi
    
    # Check AMD
    if command -v rocm-smi &> /dev/null || [ -d /sys/class/drm/card0/device/driver/amdgpu ] || lspci 2>/dev/null | grep -qi "amd.*vga\|amd.*display"; then
        has_amd=1
        echo -e "${GREEN}✓ AMD GPU detected${NC}"
        
        # Check AMF/VAAPI support
        if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_amf"; then
            echo -e "${GREEN}✓ HEVC_AMF encoder available${NC}"
        elif ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_vaapi"; then
            echo -e "${GREEN}✓ HEVC_VAAPI encoder available${NC}"
        else
            echo -e "${YELLOW}⚠ No AMD HEVC encoder available in ffmpeg${NC}"
            echo -e "${YELLOW}  Consider installing VAAPI drivers or AMF support${NC}"
        fi
    fi
    
    if [ $has_nvidia -eq 0 ] && [ $has_amd -eq 0 ]; then
        echo -e "${YELLOW}⚠ No GPU detected - will use CPU encoding${NC}"
        echo -e "${YELLOW}  Note: CPU encoding is much slower than GPU${NC}"
    fi
    
    echo ""
}

# Install the script
install_script() {
    echo -e "${BLUE}═══ Installing Script ═══${NC}"
    echo ""
    
    local install_dir="$HOME/.local/bin"
    local script_name="hyprland-video-optimizer"
    local source_script="hyprland-video-optimizer.sh"
    
    # Check if source script exists
    if [ ! -f "$source_script" ]; then
        echo -e "${RED}Error: $source_script not found${NC}"
        echo -e "${YELLOW}Make sure you're running this from the repository directory${NC}"
        exit 1
    fi
    
    # Create install directory if it doesn't exist
    mkdir -p "$install_dir"
    
    # Copy script
    cp "$source_script" "$install_dir/$script_name"
    chmod +x "$install_dir/$script_name"
    
    echo -e "${GREEN}✓ Installed to: $install_dir/$script_name${NC}"
    echo ""
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        echo -e "${YELLOW}⚠ $install_dir is not in your PATH${NC}"
        echo ""
        echo -e "${CYAN}Add the following line to your shell config:${NC}"
        echo -e "${YELLOW}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo ""
        echo -e "${CYAN}For bash: ~/.bashrc${NC}"
        echo -e "${CYAN}For zsh:  ~/.zshrc${NC}"
        echo -e "${CYAN}For fish: ~/.config/fish/config.fish${NC}"
        echo ""
        
        echo -ne "${GREEN}Add to PATH automatically?${NC} ${YELLOW}[Y/n]${NC}: "
        read -r response
        response="${response:-y}"
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            # Detect shell
            local shell_config=""
            if [ -n "$BASH_VERSION" ]; then
                shell_config="$HOME/.bashrc"
            elif [ -n "$ZSH_VERSION" ]; then
                shell_config="$HOME/.zshrc"
            fi
            
            if [ -n "$shell_config" ]; then
                echo "" >> "$shell_config"
                echo "# Added by hyprland-video-optimizer installer" >> "$shell_config"
                echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$shell_config"
                echo -e "${GREEN}✓ Added to $shell_config${NC}"
                echo -e "${YELLOW}  Run: source $shell_config${NC}"
                echo -e "${YELLOW}  Or restart your terminal${NC}"
            else
                echo -e "${YELLOW}⚠ Could not detect shell config file${NC}"
                echo -e "${YELLOW}  Please add manually${NC}"
            fi
        fi
        echo ""
    else
        echo -e "${GREEN}✓ $install_dir is already in PATH${NC}"
        echo ""
    fi
}

# Check Hyprland
check_hyprland() {
    echo -e "${BLUE}═══ Hyprland Integration ═══${NC}"
    echo ""
    
    if command -v hyprctl &> /dev/null; then
        echo -e "${GREEN}✓ Hyprland detected${NC}"
        echo -e "${GREEN}✓ Auto-resolution detection available${NC}"
        
        # Get current resolution
        local resolution=$(hyprctl monitors 2>/dev/null | grep -oP '\d+x\d+@' | head -n1 | sed 's/@$//')
        if [ -n "$resolution" ]; then
            echo -e "${GREEN}✓ Current monitor resolution: ${resolution}${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Hyprland not detected${NC}"
        echo -e "${YELLOW}  Auto-resolution detection will not be available${NC}"
        echo -e "${YELLOW}  You can still use manual resolution selection${NC}"
    fi
    
    echo ""
}

# Print completion message
print_completion() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                  ${GREEN}Installation Complete!${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✓ Hyprland Video Optimizer is ready to use!${NC}"
    echo ""
    echo -e "${CYAN}Quick Start:${NC}"
    echo -e "  ${YELLOW}hyprland-video-optimizer${NC}"
    echo ""
    echo -e "${CYAN}Sample Videos:${NC}"
    echo -e "  Check out ${YELLOW}optimized_samples/${NC} for examples"
    echo ""
    echo -e "${CYAN}Documentation:${NC}"
    echo -e "  Read ${YELLOW}README.md${NC} for detailed usage instructions"
    echo ""
    echo -e "${CYAN}Issues or Questions?${NC}"
    echo -e "  https://github.com/yourusername/hyprland-video-optimizer/issues"
    echo ""
}

# Main installation
main() {
    print_header
    check_arch
    install_dependencies
    check_gpu_support
    check_hyprland
    install_script
    print_completion
}

# Run installer
main