#!/bin/ash

# MIT License
# 
# Copyright (c) 2024 [Your Name]
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

## @file flashesp.sh
# @brief Script for flashing ESP32 firmware.
# @details This script checks for a newer firmware version, downloads it if available, 
# flashes it onto an ESP32 device, and then cleans up temporary files.

echo "Starting firmware update script."

# Define base paths
BASE_PATH="/recalbox/share/addons/azway/controller/firmware"
TOOLS_PATH="$BASE_PATH/tools"
BIN_PATH="$BASE_PATH/bin"
TEMP_DIR="/recalbox/share/addons/azway/controller/tmp/flash"

# Define specific paths
ESPTOOL_PATH="$TOOLS_PATH/esptools"
FIRMWARE_PATH="$BIN_PATH"
INSTALLED_VERSION_FILE="$BASE_PATH/installed_version.txt"

# Define URLs
FIRMWARE_URL="https://github.com/dabatnot/Azway-Retro-Controller/releases/latest/download/firmware.zip"
GITHUB_API_URL="https://api.github.com/repos/dabatnot/Azway-Retro-Controller/releases/latest"

## @brief Function to fetch the latest version number from GitHub API using wget and sed
# @return Latest version number or exits on error
fetch_latest_version() {
    wget --no-check-certificate -O "$TEMP_DIR/latest_release.json" "$GITHUB_API_URL"
    if [ -f "$TEMP_DIR/latest_release.json" ]; then
        VERSION=$(sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' "$TEMP_DIR/latest_release.json")
        echo "$VERSION"
    else
        echo "Error: Unable to fetch the latest version."
        exit 1
    fi
}

## @brief Function to compare versions
# @param $1 Version to compare
# @param $2 Version to compare against
# @return 0 if the first version is greater or equal to the second, 1 otherwise
version_greater_or_equal() {
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

## @brief Function to detect the ESP32
# @return Detected ESP32 port or "ESP32 not found"
detect_esp32() {
    for port in $(ls /dev/ttyUSB*); do
        if python3 $ESPTOOL_PATH/esptool.py --chip esp32s3 --port $port chip_id > /dev/null 2>&1; then
            echo $port
            return
        fi
    done
    echo "ESP32 not found"
}

# Ensure the temporary directory exists
mkdir -p "$TEMP_DIR"

# Fetch the latest release version
LATEST_VERSION=$(fetch_latest_version)
echo "Latest release version: $LATEST_VERSION"

# Check if there is a previously installed version
if [ -f "$INSTALLED_VERSION_FILE" ]; then
    INSTALLED_VERSION=$(cat "$INSTALLED_VERSION_FILE")
    echo "Installed version: $INSTALLED_VERSION"
else
    INSTALLED_VERSION="none"
    echo "No installed version found."
fi

# Compare versions and download the latest release if necessary
if version_greater_or_equal "$LATEST_VERSION" "$INSTALLED_VERSION"; then
    echo "The installed version is up to date or newer. No action required."
else
    echo "A newer version is available. Downloading the latest release..."
    wget --no-check-certificate -O "$TEMP_DIR/firmware.zip" "$FIRMWARE_URL"
    unzip -o "$TEMP_DIR/firmware.zip" -d "$TEMP_DIR"
    mkdir -p "$FIRMWARE_PATH"
    echo "Contents of $TEMP_DIR:"
    ls -l "$TEMP_DIR"
    cp "$TEMP_DIR/"*.bin "$FIRMWARE_PATH/"
    echo "Contents of $FIRMWARE_PATH after copying:"
    ls -l "$FIRMWARE_PATH"
    echo "Latest release downloaded and extracted."
fi

# Detect the ESP32
echo "Detecting ESP32..."
esp32_port=$(detect_esp32)

if [ "$esp32_port" != "ESP32 not found" ]; then
    echo "ESP32 detected on port: $esp32_port"
    # Check for .bin files
    bootloader_bin="$FIRMWARE_PATH/bootloader.bin"
    partitions_bin="$FIRMWARE_PATH/partitions.bin"
    firmware_bin="$FIRMWARE_PATH/firmware.bin"
    boot_app0_bin="$FIRMWARE_PATH/boot_app0.bin"
    
    if [ -f "$bootloader_bin" ] && [ -f "$partitions_bin" ] && [ -f "$firmware_bin" ] && [ -f "$boot_app0_bin" ]; then
        echo "Firmware files found:"
        echo "  Bootloader: $bootloader_bin"
        echo "  Partitions: $partitions_bin"
        echo "  Firmware: $firmware_bin"
        echo "  Boot App0: $boot_app0_bin"
        echo "Flashing ESP32..."
        python3 $ESPTOOL_PATH/esptool.py --chip esp32s3 --port $esp32_port --baud 460800 --before default_reset --after hard_reset write_flash -z \
            --flash_mode dio --flash_freq 80m --flash_size 8MB \
            0x0000 $bootloader_bin \
            0x8000 $partitions_bin \
            0xe000 $boot_app0_bin \
            0x10000 $firmware_bin
        if [ $? -eq 0 ]; then
            echo "Flashing successful!"
            # Update the installed version file
            echo "$LATEST_VERSION" > "$INSTALLED_VERSION_FILE"
            # Remove the firmware files
            rm -f "$bootloader_bin" "$partitions_bin" "$firmware_bin" "$boot_app0_bin"
        else
            echo "Error during ESP32 flashing."
        fi
    else
        echo "One or more firmware files are missing in $FIRMWARE_PATH."
    fi
else
    echo "Error: ESP32 not detected."
fi

# Clean up temporary files except the temporary directory
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR/firmware.zip"
rm -rf "$TEMP_DIR/latest_release.json"
# rm -rf "$TEMP_DIR/firmware"  # Commented out to not remove the temporary directory itself

echo "End of firmware update script."
