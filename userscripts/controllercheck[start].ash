#!/bin/sh

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

## @file controller_install.sh
# @brief Script for installing and updating the controller script and its dependencies.
# @details This script checks for the latest version of the controller script, installs necessary dependencies, and manages the script execution.

LOG_FILE="/var/log/controller_install.log"

# Redirect all output to the log file
exec > "$LOG_FILE" 2>&1

echo "Script started at: $(date)"

# Define path variables
INSTALL_DIR="/recalbox/share/addons/azway/controller"
INSTALL_FILE="$INSTALL_DIR/last_install.txt"
TEMP_DIR="$INSTALL_DIR/tmp"
SCRIPT_DIR="/recalbox/share/userscripts"
SCRIPT_NAME="controller(permanent).py"
SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"
SITE_PACKAGES_DIR="/usr/lib/python3.11/site-packages"

# Define URLs and filenames
GITHUB_API_URL="https://api.github.com/repos/dabatnot/Azway-Retro-Controller-Scripts/releases/latest"
RELEASE_BASE_URL="https://github.com/dabatnot/Azway-Retro-Controller-Scripts/releases/download"
PYSERIAL_URL="https://files.pythonhosted.org/packages/source/p/pyserial/pyserial-3.5.tar.gz"
SCRIPT_DOWNLOAD_NAME="controller.py"
LATEST_VERSION_FILE="$TEMP_DIR/latest_version.txt"

echo "Path variables defined"

# Ensure the temporary directory exists
mkdir -p "$TEMP_DIR"

## @brief Function to compare versions
# @param $1 Version to compare
# @param $2 Version to compare against
# @return 0 if the first version is greater or equal to the second, 1 otherwise
version_greater_or_equal() {
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

## @brief Function to stop the Python script if it is running
stop_running_script() {
    PID=$(pgrep -f "$SCRIPT_NAME")
    if [ ! -z "$PID" ]; then
        echo "Stopping the script $SCRIPT_NAME (PID: $PID)"
        kill -9 $PID
    fi
}

## @brief Function to start the Python script
start_script() {
    if [ -f "$SCRIPT_PATH" ]; then
        echo "Starting the script $SCRIPT_NAME"
        nohup python3 "$SCRIPT_PATH" &
    fi
}

## @brief Function to check if the pyserial library is already installed
is_pyserial_installed() {
    python3 -c "import serial" > /dev/null 2>&1
    return $?
}

## @brief Function to wait for network availability
wait_for_network() {
    echo "Waiting for network to become available..."
    while ! ping -c 1 google.com > /dev/null 2>&1; do
        echo "Network not available, retrying in 5 seconds..."
        sleep 5
    done
    echo "Network is now available."
}

## @brief Function to fetch the latest version number from GitHub API using wget and sed
# @return Latest version number or exits on error
fetch_latest_version() {
    wget --no-check-certificate -O "$LATEST_VERSION_FILE" "$GITHUB_API_URL"
    if [ -f "$LATEST_VERSION_FILE" ]; then
        VERSION=$(sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' "$LATEST_VERSION_FILE")
        echo "$VERSION"
    else
        echo "Error: Unable to fetch the latest version."
        exit 1
    fi
}

echo "Waiting for network"
# Wait for the network to be available
wait_for_network

echo "Fetching the latest version number"
# Fetch the latest version number
INSTALL_VERSION=$(fetch_latest_version)
echo "Latest version available: $INSTALL_VERSION"

# Verify INSTALL_VERSION variable is set correctly
if [ -z "$INSTALL_VERSION" ]; then
    echo "Error: INSTALL_VERSION is empty"
    exit 1
fi

# Mount the system as read/write
mount -o remount,rw /
echo "System mounted as read/write"

# Initialize a variable to track if an installation occurred
installation_done=false

# Check if the version file exists
if [ -f "$INSTALL_FILE" ]; then
    # Read the installed version
    INSTALLED_VERSION=$(cat "$INSTALL_FILE")
    echo "Installed version: $INSTALLED_VERSION"

    # Compare versions
    if version_greater_or_equal "$INSTALL_VERSION" "$INSTALLED_VERSION"; then
        echo "The installed version is up to date or newer. No action required."
    else
        echo "An older version is installed. Update required."
        installation_done=true
    fi
else
    echo "No installed version found. Installation required."
    installation_done=true
fi

# Proceed with installation only if necessary
if [ "$installation_done" = true ]; then
    echo "Installation needed"
    # Stop the Python script if it is running
    stop_running_script

    # Check if pyserial is already installed
    if is_pyserial_installed; then
        echo "pyserial is already installed. No reinstallation needed."
    else
        # Execute the installation script for pyserial
        mkdir -p "$TEMP_DIR"
        cd "$TEMP_DIR"
        wget --no-check-certificate "$PYSERIAL_URL"
        tar -xzf pyserial-3.5.tar.gz
        cp -r pyserial-3.5/serial "$SITE_PACKAGES_DIR"
        cd ..
        rm -rf "$TEMP_DIR"
    fi

    # Download the latest release from GitHub
    wget --no-check-certificate -O "$TEMP_DIR/release.tar.gz" "$RELEASE_BASE_URL/$INSTALL_VERSION/release.tar.gz"
    tar -xzf "$TEMP_DIR/release.tar.gz" -C "$TEMP_DIR"

    # Update the controller(permanent).py script
    cd "$SCRIPT_DIR"
    rm -f "$SCRIPT_NAME"
    cp "$TEMP_DIR/yourrepository-$INSTALL_VERSION/controller.py" "$SCRIPT_DOWNLOAD_NAME"
    mv "$SCRIPT_DOWNLOAD_NAME" "$SCRIPT_NAME"

    # Create the version storage directory if needed
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
    fi

    # Update the version file
    echo "$INSTALL_VERSION" > "$INSTALL_FILE"
    sync
    echo "Updated version file with: $INSTALL_VERSION"

    # Verify the version file
    VERIFIED_VERSION=$(cat "$INSTALL_FILE")
    if [ "$VERIFIED_VERSION" != "$INSTALL_VERSION" ]; then
        echo "Error: Version file verification failed. Expected $INSTALL_VERSION but got $VERIFIED_VERSION"
        exit 1
    fi
fi

# Mount the system as read-only
mount -o remount,r /
echo "System mounted as read-only"

# Reboot the system only if an installation was done
if [ "$installation_done" = true ]; then
    echo "REBOOTING..."
    #reboot
else
    # Restart the Python script if it was stopped
    start_script
fi

echo "Script ended at: $(date)"
