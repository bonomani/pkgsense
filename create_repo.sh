#!/bin/bash
# Script to populate the FreeBSD repository with packages, create symlinks for the latest versions, and create repo metadata.

set -e  # Exit immediately if a command fails

# Configurable variables
BASE_DIR=$(pwd)  # The current working directory
PKGDIR_PATH="${BASE_DIR}/packages"  # Packages directory located inside the CWD
GLOBAL_REPO_DIR="${BASE_DIR}/repo"  # Global repository directory

# Ensure the repo directory exists and is clean
if [ -d "${GLOBAL_REPO_DIR}" ]; then
    echo "✅ Repo directory exists. Cleaning up old files."
    rm -rf "${GLOBAL_REPO_DIR}/*"  # Clean the repo directory
else
    echo "✅ Repo directory does not exist. Creating it."
    mkdir -p "${GLOBAL_REPO_DIR}"  # Create the directory if it doesn't exist
fi

# Function to log the operation
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Loop through each package directory and build them dynamically
for pkg_dir in "${PKGDIR_PATH}"/*; do
    if [ -d "$pkg_dir" ]; then
        cd "$pkg_dir"
        log_message "Building package: $(basename $pkg_dir)"
        
        # Build each package dynamically
        if [ -f "./build.sh" ]; then
            bash ./build.sh  # Assuming the package has a build.sh script
        else
            log_message "🚨 No build script found for $(basename $pkg_dir), skipping."
            continue
        fi

        # Check if the 'repo' subdirectory exists and has .txz packages
        REPO_SUBDIR="${pkg_dir}/repo"
        if [ -d "$REPO_SUBDIR" ]; then
            log_message "✅ Found repo directory in ${pkg_dir}. Copying entire package structure to global repo directory."

            # Copy the entire directory structure from the package repo to the global repo
            cp -r "${REPO_SUBDIR}/" "${GLOBAL_REPO_DIR}/"
            log_message "✅ Package structure copied to: ${GLOBAL_REPO_DIR}/"
        else
            log_message "🚨 Repo subdirectory not found in ${pkg_dir}, skipping."
        fi

        cd ..  # Move back to the base directory
    fi
done

# Create the FreeBSD repository metadata using pkg repo
log_message "🛠 Creating FreeBSD repository metadata..."

# Run pkg repo on the 'All/' directory within each version-specific repo folder (this will include the metadata generation)
for repo_dir in "${GLOBAL_REPO_DIR}"/*; do
    if [ -d "${repo_dir}/All" ]; then
        log_message "Running pkg repo for: ${repo_dir}"
        pkg repo "${repo_dir}"
        log_message "✅ Repository metadata created for: ${repo_dir}"
    fi
done

# Create the 'latest' symlink for each package version at the repo level
log_message "🛠 Creating 'latest' symlinks at the repo level for the most recent version..."

for repo_version in $(echo "$REPOS" | tr -d '"'); do
    repo_name=$(echo "$repo_version" | cut -d '/' -f1)
    version=$(echo "$repo_version" | cut -d '/' -f2)

    log_message "Processing repo/version: $repo_name/$version"

    # Loop through architectures
    for arch in $(echo "$ARCHS" | tr -d '"'); do
        target_dir="${GLOBAL_REPO_DIR}/${repo_name}:${version}:${arch}"

        # Check if there's a package in the repo directory for the latest version
        if [ -d "${target_dir}/All" ] && [ "$(ls -A ${target_dir}/All)" ]; then
            latest_package=$(ls -t ${target_dir}/All/*.txz | head -n 1)  # Get the latest package by timestamp
            ln -s "${latest_package}" "${target_dir}/latest.txz"  # Create symlink to latest package
            log_message "✅ 'latest' symlink created for: ${target_dir}/latest.txz"
        fi
    done
done

# Final verification of the repo directory
log_message "Listing contents of the repo directory (${GLOBAL_REPO_DIR}):"
ls -al "${GLOBAL_REPO_DIR}"

log_message "✅ Repo metadata created and 'latest' symlinks established."

