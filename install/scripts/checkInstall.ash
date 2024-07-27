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

#v0.1.0

# Base Path
BASE_PATH="/recalbox/share/addons/azway/controller"

# Configuration Variables
LOG_FILE="$BASE_PATH/logs/main.log"  # Path to the log file
INSTALL_VERSION_FILE="$BASE_PATH/installed_version.txt"  # Path to the installed version file for Azway-Retro-Controller-Install
FIRMWARE_VERSION_FILE="$BASE_PATH/firmware/installed_version.txt"  # Path to the installed firmware version file for Azway-Retro-Controller
DESTINATION_DIR="$BASE_PATH/install"  # Destination directory for downloading and unzipping files
REPO1="dabatnot/Azway-Retro-Controller-Install"  # Repository 1 to check for updates
REPO2="dabatnot/Azway-Retro-Controller"  # Repository 2 to check for updates
FILE_NAME="controller.zip"  # Name of the file to download
INSTALL_SCRIPT="$BASE_PATH/install/dependencies/install_dependances.ash"  # Path to the install dependencies script
FLASH_SCRIPT="$BASE_PATH/install/flash/flash.ash"  # Path to the flash script
CONTROLLER_SCRIPT="$BASE_PATH/scripts/controller.py"  # Path to the controller script
POST_INSTALL_SCRIPT="$BASE_PATH/scripts/postInstall.ash"  # Path to the post install script
SCRIPTS_DIR="$BASE_PATH/scripts"  # Directory for scripts
INSTALL_SCRIPTS_DIR="$BASE_PATH/install/scripts"  # Directory for installation scripts

# Create log directory and file, and setup logging
mkdir -p "$(dirname "$LOG_FILE")"
> "$LOG_FILE"  # Purge the log file at the beginning of each run
exec > >(tee -a "$LOG_FILE") 2>&1

##
# @brief Function to get the latest release tag from a GitHub repository
# @param repo The repository name in the format "owner/repo"
# @return The latest release tag
##
get_latest_release() {
    repo=$1
    latest_release=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$latest_release" ]; then
        echo "Failed to get the latest release for $repo"  # Debugging line
    fi
    echo "$latest_release"
}

##
# @brief Function to download the latest release zip file to a specific directory
# @param repo The repository name in the format "owner/repo"
# @param file_name The name of the file to download
# @param destination_dir The directory where the file will be downloaded
##
download_latest_release() {
    repo=$1
    file_name=$2
    destination_dir=$3
    url="https://github.com/$repo/releases/latest/download/$file_name"
    
    # Create the directory if it doesn't exist
    mkdir -p "$destination_dir"
    
    # Download the file to the specified directory
    curl -L -o "$destination_dir/$file_name" "$url"
}

##
# @brief Function to clean the destination directory
# @param dir The directory to be cleaned
##
clean_directory() {
    dir=$1
    rm -rf "$dir"/*
}

##
# @brief Function to unzip the downloaded file directly into the specified directory
# @param file_path The path to the zip file
# @param destination_dir The directory where the file will be unzipped
##
unzip_file() {
    file_path=$1
    destination_dir=$2

    # Unzip the file into the destination directory, preserving the hierarchy
    unzip -o "$file_path" -d "$destination_dir"

    # Move files from the created sub-directory to the destination directory
    sub_dir=$(unzip -Z1 "$file_path" | head -n 1 | awk -F"/" '{print $1}')
    if [ -d "$destination_dir/$sub_dir" ]; then
        mv "$destination_dir/$sub_dir"/* "$destination_dir/"
        rm -rf "$destination_dir/$sub_dir"
    fi
}

##
# @brief Function to run a script
# @param script_path The path to the script to be executed
##
run_script() {
    script_path=$1

    # Check if the script exists and flag it as executable
    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
        sh "$script_path"
        if [ $? -ne 0 ]; then
            echo "Script $script_path encountered an error"
            exit 1
        fi
    else
        echo "Script $script_path not found"
        exit 1
    fi
}

##
# @brief Function to compare version strings
# @param $@ The versions to be compared
# @return True if the first version is greater than the second, False otherwise
##
version_greater() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# Get the latest releases
latest_release1=$(get_latest_release $REPO1)
latest_release2=$(get_latest_release $REPO2)

# Output the latest releases
echo "Latest release for $REPO1: $latest_release1"
echo "Latest release for $REPO2: $latest_release2"

# Check the installed version for Azway-Retro-Controller-Install
if [ -f "$INSTALL_VERSION_FILE" ]; then
    installed_version1=$(cat "$INSTALL_VERSION_FILE")
else
    installed_version1="v0.0.0"
fi

# Download the latest release for REPO1 only if the latest release is greater
update_done=false
if version_greater "$latest_release1" "$installed_version1"; then
    clean_directory "$DESTINATION_DIR"  # Clean the destination directory before unzipping
    download_latest_release "$REPO1" "$FILE_NAME" "$DESTINATION_DIR"

    # Unzip the downloaded file without creating subfolders
    unzip_file "$DESTINATION_DIR/$FILE_NAME" "$DESTINATION_DIR"

    # Clean up the zip file
    rm "$DESTINATION_DIR/$FILE_NAME"

    # Update the installed version file for Azway-Retro-Controller-Install
    echo "$latest_release1" > "$INSTALL_VERSION_FILE"

    # Run the install_dependances.ash script
    run_script "$INSTALL_SCRIPT"

    rm -rf "$SCRIPTS_DIR"
    mkdir "$SCRIPTS_DIR"
    cp "$INSTALL_SCRIPTS_DIR/postInstall.ash" "$SCRIPTS_DIR/postInstall.ash"
    cp "$INSTALL_SCRIPTS_DIR/controller.py" "$SCRIPTS_DIR/controller.py"
    cp "$INSTALL_SCRIPTS_DIR/checkInstall.ash" "$SCRIPTS_DIR/checkInstall.ash"

    update_done=true
    echo "Downloaded, unzipped, and ran install_dependances.ash for $REPO1"
else
    echo "No update needed for $REPO1"
fi

# Check the installed firmware version for Azway-Retro-Controller
if [ -f "$FIRMWARE_VERSION_FILE" ]; then
    installed_version2=$(cat "$FIRMWARE_VERSION_FILE")
else
    installed_version2="v0.0.0"
fi

# Compare versions and run the flash script if the latest release is greater
if version_greater "$latest_release2" "$installed_version2"; then
    run_script "$FLASH_SCRIPT"
    echo "$latest_release2" > "$FIRMWARE_VERSION_FILE"
    update_done=true
    echo "Downloaded, unzipped, ran install_dependances.ash, and ran flash.ash if needed for $REPO2"
else
    echo "No update needed for $REPO2 firmware"
fi

# Launch controller.py
#echo "Running controller script"
#nohup python3 "$CONTROLLER_SCRIPT" &
#controller_pid=$!
#disown $controller_pid

# Running post install task
if [ "$update_done" = true ]; then
    echo "Running post install script"
    nohup sh "$POST_INSTALL_SCRIPT" &
    post_install_pid=$!
    disown $post_install_pid
fi

echo "Exiting main script"
exit 0