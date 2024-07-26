#!/bin/ash

# Function to get the latest release tag from a GitHub repository
get_latest_release() {
    repo=$1
    latest_release=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "$latest_release"
}

# Function to download the latest release zip file to a specific directory
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

# Function to clean the destination directory
clean_directory() {
    dir=$1
    rm -rf "$dir"/*
}

# Function to unzip the downloaded file directly into the specified directory
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

# Function to run a script
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

# Function to compare version strings
version_greater() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# Repositories to check
repo1="dabatnot/Azway-Retro-Controller-Install"
repo2="dabatnot/Azway-Retro-Controller"

# Get the latest releases
latest_release1=$(get_latest_release $repo1)
latest_release2=$(get_latest_release $repo2)

# Output the latest releases
echo "Latest release for $repo1: $latest_release1"
echo "Latest release for $repo2: $latest_release2"

# Download the latest release for repo1 to the specified directory
file_name="controller.zip"
destination_dir="/recalbox/share/addons/azway/controller/install"
clean_directory $destination_dir  # Clean the destination directory before unzipping
download_latest_release $repo1 $file_name $destination_dir

# Unzip the downloaded file without creating subfolders
unzip_file "$destination_dir/$file_name" $destination_dir

# Clean up the zip file
rm "$destination_dir/$file_name"

# Run the install_dependances.sh script
install_script="/recalbox/share/addons/azway/controller/install/dependencies/install_dependances.sh"
run_script $install_script

# Check the installed firmware version
installed_version_file="/recalbox/share/addons/azway/controller/firmware/instelled_version.txt"
if [ -f "$installed_version_file" ]; then
    installed_version=$(cat "$installed_version_file")
else
    installed_version="v0.0.0"
fi

# Compare versions and run the flash script if the latest release is greater
if version_greater "$latest_release2" "$installed_version"; then
    flash_script="/recalbox/share/addons/azway/controller/install/flash/flash.sh"
    run_script $flash_script
    echo "$latest_release2" > "$installed_version_file"
fi

echo "Downloaded, unzipped, ran install_dependances.sh, and ran flash.sh if needed for $repo1"
