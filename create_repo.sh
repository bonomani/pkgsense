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

# Run pkg repo on the parent folder of 'All/' directory
log_message "🛠 Generating metadata by running pkg repo on the parent folder of 'All/'..."

for repo_dir in "${GLOBAL_REPO_DIR}"/*; do
    # Check if the directory contains the 'All/' directory
    if [ -d "${repo_dir}/All" ]; then
        log_message "Running pkg repo for: ${repo_dir}"

        # List the contents of the 'All' directory for verification
        ls -al "${repo_dir}/All"

        # Run pkg repo on the parent folder of All/ (the repo_dir itself)
        pkg repo "${repo_dir}"

        log_message "✅ Repository metadata created for: ${repo_dir}"
    fi
done

# Create the 'latest' symlink inside the 'latest/' directory for each repo directory
log_message "🛠 Creating 'latest' symlinks inside the 'latest/' directory..."

# Loop through each repo directory in the global repo directory
for repo_dir in "${GLOBAL_REPO_DIR}"/*; do
    # Ensure that we only process directories
    if [ -d "$repo_dir" ]; then
        log_message "Processing repo directory: $repo_dir"

        # Check if there's an 'All' directory inside the repo directory
        if [ -d "${repo_dir}/All" ] && [ "$(ls -A ${repo_dir}/All)" ]; then
            # Get the latest package by timestamp
            latest_package=$(ls -t ${repo_dir}/All/*.pkg | head -n 1)

            # Ensure the 'latest' directory exists
            mkdir -p "${repo_dir}/latest"

            # Create the symlink inside the 'latest' folder pointing to the most recent package
            ln -s "../../All/$(basename "$latest_package")" "${repo_dir}/latest/$(basename "$latest_package")"
            log_message "✅ 'latest' symlink created for: ${repo_dir}/latest/$(basename "$latest_package")"
        fi
    fi
done


# Final verification of the repo directory
log_message "Listing contents of the repo directory (${GLOBAL_REPO_DIR}):"
ls -al "${GLOBAL_REPO_DIR}"

log_message "✅ Repo metadata created and 'latest' symlinks established."

