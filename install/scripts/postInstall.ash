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

# Base Path
BASE_PATH="/recalbox/share/addons/azway/controller"
USER_SCRIPTS_PATH="/recalbox/share/userscripts"

# Script Names
CHECK_INSTALL_SCRIPT="checkInstall.ash"
CHECK_INSTALL_SYNC_SCRIPT="checkInstall[start](sync).ash"

# Paths to Scripts
CHECK_INSTALL_SCRIPT_PATH="$BASE_PATH/scripts/$CHECK_INSTALL_SCRIPT"
CHECK_INSTALL_SYNC_SCRIPT_PATH="$USER_SCRIPTS_PATH/$CHECK_INSTALL_SYNC_SCRIPT"

##
# @brief Function to wait for a script to finish
# @param script_name The name of the script to wait for
##
wait_for_script() {
    script_name=$1
    echo "Waiting for $script_name to finish..."
    while ps | grep -v grep | grep "$script_name" > /dev/null; do
        sleep 1
    done
    echo "$script_name exited"
}

# Wait for checkInstall.ash to finish
wait_for_script "$CHECK_INSTALL_SCRIPT"

# Wait for checkInstall[start](sync).ash to finish
wait_for_script "$CHECK_INSTALL_SYNC_SCRIPT"

# Remove Install directory
echo "Removing install dir..."
rm -rf "$BASE_PATH/install"
echo "Removed install dir"

# Update existing checkInstall[start](sync).ash script
echo "Updating checkInstall[start](sync).ash script..."
rm "$CHECK_INSTALL_SYNC_SCRIPT_PATH"
mv "$CHECK_INSTALL_SCRIPT_PATH" "$CHECK_INSTALL_SYNC_SCRIPT_PATH"

echo "Update completed."

exit 0
