#!/usr/bin/env bash

# Hyprland Video Optimizer - Uninstaller
# Removes the video optimizer script and reverts PATH changes.

set -e

# Colors
# Using ANSI C quoting ($'...') for robust escape sequence interpretation
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[1;33m'
BLUE=$'\e[0;34m'
CYAN=$'\e[0;36m'
MAGENTA=$'\e[0;35m'
NC=$'\e[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="hyprland-video-optimizer"
INSTALL_PATH="$INSTALL_DIR/$SCRIPT_NAME"
PATH_IDENTIFIER="# Added by hyprland-video-optimizer installer"

# Print header
print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}       ${MAGENTA}Hyprland Video Optimizer Uninstaller${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Remove the installed script
remove_script() {
    echo -e "${CYAN}═══ Removing Script ═══${NC}"
    
    if [ -f "$INSTALL_PATH" ]; then
        rm -f "$INSTALL_PATH"
        echo -e "${GREEN}✓ Successfully removed: ${INSTALL_PATH}${NC}"
    else
        echo -e "${YELLOW}⚠ Script not found at ${INSTALL_PATH}${NC}"
    fi
    echo ""
}

# Revert PATH changes in shell configuration files
revert_path_changes() {
    echo -e "${CYAN}═══ Reverting PATH Changes ═══${NC}"
    
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish")
    local reverted=0
    
    for config_file in "${shell_configs[@]}"; do
        if [ -f "$config_file" ]; then
            # Check if the identifier exists in the file
            if grep -qF "$PATH_IDENTIFIER" "$config_file"; then
                echo -e "${YELLOW}Processing ${config_file}...${NC}"
                
                # Use sed to find the identifier and delete that line and the line immediately following it (the export command)
                # Creates a backup file: $config_file.bak
                sed -i.bak "/$PATH_IDENTIFIER/,+1d" "$config_file"
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ Removed PATH entry from ${config_file}${NC}"
                    echo -e "${YELLOW}  Backup created: ${config_file}.bak${NC}"
                    reverted=1
                else
                    echo -e "${RED}✗ Failed to automatically remove PATH entry from ${config_file}${NC}"
                    echo -e "${YELLOW}  Please check the file manually.${NC}"
                fi
            fi
        fi
    done
    
    if [ $reverted -eq 0 ]; then
        echo -e "${GREEN}✓ No automatic PATH changes were found to revert.${NC}"
    fi
    
    echo ""
}

# Final summary and user instructions
print_completion() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                   ${GREEN}Uninstallation Complete!${NC}                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${GREEN}✓ The Hyprland Video Optimizer script has been removed.${NC}"
    echo ""
    
    echo -e "${MAGENTA}Cleanup Steps (Manual):${NC}"
    
    # 1. Dependency Note
    echo -e "${YELLOW}1. System Dependencies:${NC}"
    # Fixed Markdown bolding (**) to use shell color codes
    echo "   The installer may have installed system packages like ${YELLOW}ffmpeg${NC}, ${YELLOW}jq${NC}, and ${YELLOW}bc${NC}."
    echo "   These are ${YELLOW}NOT${NC} removed automatically as they may be required by other programs."
    echo "   If you want to remove them and they are not needed elsewhere, use your package manager:"
    echo "     ${CYAN}sudo pacman -R ffmpeg jq bc${NC}"
    echo ""

    # 2. Config Source Note
    echo -e "${YELLOW}2. Shell Configuration:${NC}"
    # Fixed Markdown bolding (**) to use shell color codes
    echo "   If your shell was running during uninstallation, you must ${YELLOW}reload your configuration${NC}:"
    echo "     ${CYAN}source ~/.bashrc${NC} or ${CYAN}source ~/.zshrc${NC}"
    echo "   (Or simply restart your terminal)"
    echo ""
}

# Main function
main() {
    print_header
    
    # Confirm removal
    echo -ne "${RED}WARNING: This will remove the installed script. Proceed?${NC} ${YELLOW}[Y/n]${NC}: "
    read -r response
    response="${response:-y}"
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Uninstallation cancelled.${NC}"
        exit 0
    fi
    
    remove_script
    revert_path_changes
    print_completion
}

# Run uninstaller
main