#!/bin/ash

# MIT License
# 
# Copyright (c) 2024 [Your Name]
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, et/ou sell
# copies of the Software, et to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice et this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE ET NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

## @file flashesp.sh
# @brief Script for flashing ESP32 firmware.
# @details This script checks for a newer firmware version, downloads it if available,
# flashes it onto an ESP32 device, et then cleans up temporary files.

# Define paths
BASE_PATH="/recalbox/share/addons/azway/controller/firmware"
TOOLS_PATH="$BASE_PATH/tools"
BIN_PATH="$BASE_PATH/bin"
LIBS_PATH="/recalbox/share/addons/azway/controller/libs"
TEMP_DIR="/recalbox/share/addons/azway/controller/tmp/flash"
LOG_DIR="/recalbox/share/addons/azway/controller/logs"
LOG_FILE="$LOG_DIR/flash.log"
INSTALLED_VERSION_FILE="$BASE_PATH/installed_version.txt"

# Create necessary directories
mkdir -p "$TEMP_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$BASE_PATH"

# Redirect all output et errors to the log file
exec > "$LOG_FILE" 2>&1

# Function to log messages with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Starting firmware update script."

# Define specific paths
ESPTOOL_PATH="$TOOLS_PATH/esptool/esptool.py"
FIRMWARE_PATH="$BIN_PATH"

# Define URLs
FIRMWARE_URL="https://github.com/dabatnot/Azway-Retro-Controller/releases/latest/download/firmware.zip"
GITHUB_API_URL="https://api.github.com/repos/dabatnot/Azway-Retro-Controller/releases/latest"

## @brief Function to fetch the latest version number from GitHub API using wget et Python
# @return Latest version number or exits on error
fetch_latest_version() {
    log "Fetching the latest firmware version from GitHub."
    wget --no-check-certificate -O "$TEMP_DIR/latest_release.json" "$GITHUB_API_URL" >> "$LOG_FILE" 2>&1
    if [ -f "$TEMP_DIR/latest_release.json" ]; then
        VERSION=$(python3 -c "import json; f = open('$TEMP_DIR/latest_release.json'); data = json.load(f); f.close(); print(data['tag_name'])")
        log "Latest version fetched: $VERSION"
        echo "$VERSION"
    else
        log "Error: Unable to fetch the latest version."
        exit 1
    fi
}

## @brief Function to compare versions
# @param $1 Version to compare
# @param $2 Version to compare against
# @return 0 if the first version is greater or equal to the second, 1 otherwise
version_greater_or_equal() {
    log "Comparing versions: $1 et $2"
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

## @brief Function to detect the ESP32
# @return Detected ESP32 port or "ESP32 not found"
detect_esp32() {
    log "Detecting connected ESP32 devices."
    for port in $(ls /dev/ttyUSB* 2>/dev/null); do
        if PYTHONPATH="$LIBS_PATH" python3 "$ESPTOOL_PATH" --chip esp32s3 --port $port chip_id > /dev/null 2>&1; then
            log "ESP32 detected on port: $port"
            echo $port
            return
        fi
    done
    log "ESP32 not found"
    echo "ESP32 not found"
}

# Function to run esptool with the correct environment
run_esptool() {
    log "Running esptool with arguments: $@"
    PYTHONPATH="$LIBS_PATH" python3 "$ESPTOOL_PATH" "$@" >> "$LOG_FILE" 2>&1
}

# Ensure the temporary directory exists
mkdir -p "$TEMP_DIR"

# Fetch the latest release version
LATEST_VERSION=$(fetch_latest_version)
log "Latest release version: $LATEST_VERSION"

# Check if there is a previously installed version
if [ -f "$INSTALLED_VERSION_FILE" ]; then
    INSTALLED_VERSION=$(cat "$INSTALLED_VERSION_FILE" | tr -d '\n')
    log "Installed version: $INSTALLED_VERSION"
else
    INSTALLED_VERSION="none"
    log "No installed version found."
fi

# Download and install the latest release if no version is installed or a newer version is available
if [ "$INSTALLED_VERSION" = "none" ] || ! version_greater_or_equal "$INSTALLED_VERSION" "$LATEST_VERSION"; then
    log "A newer version is available. Downloading the latest release..."
    wget --no-check-certificate -O "$TEMP_DIR/firmware.zip" "$FIRMWARE_URL" >> "$LOG_FILE" 2>&1
    log "Extracting firmware.zip to $TEMP_DIR"
    unzip -o "$TEMP_DIR/firmware.zip" -d "$TEMP_DIR" >> "$LOG_FILE" 2>&1
    mkdir -p "$FIRMWARE_PATH"
    log "Contents of $TEMP_DIR:"
    ls -l "$TEMP_DIR" >> "$LOG_FILE" 2>&1
    cp "$TEMP_DIR/"*.bin "$FIRMWARE_PATH/"
    log "Contents of $FIRMWARE_PATH after copying:"
    ls -l "$FIRMWARE_PATH" >> "$LOG_FILE" 2>&1
    log "Latest release downloaded et extracted."
else
    log "The installed version is up to date or newer. No action required."
fi

# Detect the ESP32
log "Detecting ESP32..."
esp32_port=$(detect_esp32)

if [ "$esp32_port" != "ESP32 not found" ]; then
    log "ESP32 detected on port: $esp32_port"
    # Check for .bin files
    bootloader_bin="$FIRMWARE_PATH/bootloader.bin"
    partitions_bin="$FIRMWARE_PATH/partitions.bin"
    firmware_bin="$FIRMWARE_PATH/firmware.bin"
    boot_app0_bin="$FIRMWARE_PATH/boot_app0.bin"
    
    if [ -f "$bootloader_bin" ] && [ -f "$partitions_bin" ] && [ -f "$firmware_bin" ] && [ -f "$boot_app0_bin" ]; then
        log "Firmware files found:"
        log "  Bootloader: $bootloader_bin"
        log "  Partitions: $partitions_bin"
        log "  Firmware: $firmware_bin"
        log "  Boot App0: $boot_app0_bin"
        log "Flashing ESP32..."
        run_esptool --chip esp32s3 --port $esp32_port --baud 460800 --before default_reset --after hard_reset write_flash -z \
            --flash_mode dio --flash_freq 80m --flash_size 8MB \
            0x0000 $bootloader_bin \
            0x8000 $partitions_bin \
            0xe000 $boot_app0_bin \
            0x10000 $firmware_bin
        if [ $? -eq 0 ]; then
            log "Flashing successful!"
            # Update the installed version file
            log "Updating installed version file to: $LATEST_VERSION"
            echo "$LATEST_VERSION" > "$INSTALLED_VERSION_FILE"
            log "Installed version updated to: $LATEST_VERSION"
            # Remove the firmware files
            rm -f "$bootloader_bin" "$partitions_bin" "$firmware_bin" "$boot_app0_bin"
        else
            log "Error during ESP32 flashing."
        fi
    else
        log "One or more firmware files are missing in $FIRMWARE_PATH."
    fi
else
    log "Error: ESP32 not detected."
fi

# Clean up temporary files except the temporary directory
log "Cleaning up temporary files..."
rm -rf "$TEMP_DIR/firmware.zip"
rm -rf "$TEMP_DIR/latest_release.json"
# rm -rf "$TEMP_DIR/firmware"  # Commented out to not remove the temporary directory itself

log "End of firmware update script."
