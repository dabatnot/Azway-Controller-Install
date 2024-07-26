#!/bin/ash

# Function to get the latest release tag from a GitHub repository
get_latest_release() {
    repo=$1
    latest_release=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "$latest_release"
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
