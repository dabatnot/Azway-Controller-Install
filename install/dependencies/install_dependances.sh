#!/bin/ash

# MIT License
# 
# Copyright (c) 2024 Dabatnot
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

# Define file and directory paths

DEST_DIR="/recalbox/share/addons/azway/controller"
LIBS_ZIP="$DEST_DIR/install/libs/libs.zip"
ESPTOOL_ZIP="$DEST_DIR/install/libs/esptool.zip"
LIBS_DIR="./libs"
TEMP_DIR="/recalbox/share/addons/azway/controller/tmp/esptool_temp"
ESPTOOL_DEST_DIR="/recalbox/share/addons/azway/controller/firmware/tools/esptool"
LOG_DIR="/recalbox/share/addons/azway/controller/logs"
LOG_FILE="$LOG_DIR/dependencies.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Ensure the log file exists
touch "$LOG_FILE"
if [ $? -ne 0 ]; then
    echo "Failed to create or write to log file: $LOG_FILE"
    exit 1
fi

# Redirect all output to the log file
exec > "$LOG_FILE" 2>&1

# Function to log messages with date/time
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Log directory created or already exists: $LOG_DIR"

log "Script started."

# Check if the libs.zip file exists
if [ -f "$LIBS_ZIP" ]; then
    log "The libs.zip file exists. Decompressing..."
    # Remove the contents of the destination directory except for libs.zip
    find "$DEST_DIR/libs" -mindepth 1 ! -name 'libs.zip' -exec rm -rf {} +
    log "Destination directory created or already exists: $DEST_DIR"
    # Decompress the libs.zip file into the destination directory
    if unzip -o -u "$LIBS_ZIP" -d "$DEST_DIR"; then
        log "libs.zip decompression completed."
    else
        log "libs.zip decompression failed."
        exit 1
    fi
else
    log "The libs.zip file does not exist. Please check the file path."
    exit 1
fi

# Check if the esptool.zip file exists
if [ -f "$ESPTOOL_ZIP" ]; then
    log "The esptool.zip file exists. Decompressing..."
    # Create a temporary directory for esptool decompression
    mkdir -p "$TEMP_DIR"
    log "Temporary directory created: $TEMP_DIR"
    # Decompress the esptool.zip file into the temporary directory
    if unzip -o -u "$ESPTOOL_ZIP" -d "$TEMP_DIR"; then
        log "esptool.zip decompression completed in temporary directory."
    else
        log "esptool.zip decompression failed."
        exit 1
    fi
    
    # Clear the content of the destination directory
    rm -rf "$ESPTOOL_DEST_DIR"/*
    log "Esptool destination directory cleared: $ESPTOOL_DEST_DIR"
    
    # Move the content from the temporary directory to the destination directory
    mkdir -p "$ESPTOOL_DEST_DIR"
    log "Esptool destination directory created or already exists: $ESPTOOL_DEST_DIR"
    if mv "$TEMP_DIR"/esptool-master/* "$ESPTOOL_DEST_DIR"; then
        log "esptool files moved to the destination directory."
    else
        log "Moving esptool files failed."
        exit 1
    fi

    # Remove the temporary directory
    rm -rf "$TEMP_DIR"
    log "Temporary directory has been removed."
else
    log "The esptool.zip file does not exist. Please check the file path."
    exit 1
fi

# Remove the libs directory
#rm -rf "$LIBS_DIR"
log "The libs directory has been removed."

log "Script completed."
