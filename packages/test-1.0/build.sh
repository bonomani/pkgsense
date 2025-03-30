#!/bin/bash
# Build script for pfSense package

set -e  # Exit immediately if a command fails

# Get the package name and version dynamically from the current folder
PKGDIR_NAME=$(basename "$PWD")  # This assumes the current folder is named as "pkgname-version"
PKGNAME=$(echo "$PKGDIR_NAME" | cut -d '-' -f1)
PKGVERSION=$(echo "$PKGDIR_NAME" | cut -d '-' -f2)

# If the folder is structured as "name-version", this will extract them
log_message "Detected package name: $PKGNAME"
log_message "Detected package version: $PKGVERSION"

# Full path of the current package directory
PKGDIR_PATH=$(pwd)
log_message "Full path of the package directory: ${PKGDIR_PATH}"

# Define the repo directory and manifest path using the full path
REPO_DIR="${PKGDIR_PATH}/repo"  # Repo directory will be inside the current folder
MANIFEST_FILE="${PKGNAME}-${PKGVERSION}/+MANIFEST"  # Path to the +MANIFEST file

# Log file for the build process
LOG_FILE="build.log"

# Function to log messages with timestamps
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_FILE}"
}

# Check for required commands
check_command() {
    command_name=$1
    command -v "$command_name" &> /dev/null || { log_message "🚨 $command_name is not installed! Please install $command_name to continue."; exit 1; }
}

# Check if jq is installed
check_command "jq"

# Check if pkg is installed
check_command "pkg"

# Function to check if a file exists
check_file_exists() {
    if [ ! -f "$1" ]; then
        log_message "🚨 File missing: $1"
        exit 1
    else
        log_message "✅ File found: $1"
    fi
}

# Function to check if a directory exists
check_directory_exists() {
    if [ ! -d "$1" ]; then
        log_message "🚨 Directory missing: $1"
        exit 1
    else
        log_message "✅ Directory found: $1"
    fi
}

# Function to validate PKGNAME and PKGVERSION in the +MANIFEST file
validate_manifest() {
    log_message "Validating PKGNAME and PKGVERSION in the +MANIFEST file..."

    # Check if the +MANIFEST file contains the expected fields
    if ! jq -e ".name == \"$PKGNAME\"" "${MANIFEST_FILE}" &>/dev/null; then
        log_message "🚨 PKGNAME ($PKGNAME) is not correctly set in the +MANIFEST file."
        exit 1
    fi

    if ! jq -e ".version == \"$PKGVERSION\"" "${MANIFEST_FILE}" &>/dev/null; then
        log_message "🚨 PKGVERSION ($PKGVERSION) is not correctly set in the +MANIFEST file."
        exit 1
    fi

    log_message "✅ PKGNAME and PKGVERSION are correctly set in the +MANIFEST file."
}

# Function to parse the +MANIFEST file to extract necessary data
parse_manifest() {
    log_message "Parsing +MANIFEST file..."
    
    file_structure=$(jq -r '.file_structure' "${MANIFEST_FILE}")
    
   # Extract the repo info from the +MANIFEST
    repo_info=$(jq -r '.repo[] | .name as $name | .versions[] | "\($name)/\(. )"' "${MANIFEST_FILE}")
    architectures=$(jq -r '.architectures | join(", ")' "${MANIFEST_FILE}")

    log_message "✅ Parsed repo and architectures."

    # Set REPOS and ARCHS variables
    REPOS=$(echo "$repo_info")
    ARCHS=$(echo "$architectures")

    log_message "✅ Repositories and architectures parsed."
}

# Function to check the file structure based on the +MANIFEST
check_file_structure() {
   
    log_message "Checking file structure..."

    # Loop through each entry in the file structure and check if files and directories exist
    for entry in $(echo "$file_structure" | jq -r '.[]'); do
        # Extract file path or directory
        path=$(echo "$entry" | jq -r '.path')

        # Check if it's a directory or a file
        if [[ "$path" == */ ]]; then
            check_directory_exists "${PKGNAME}-${PKGVERSION}/${path}"
        else
            check_file_exists "${PKGNAME}-${PKGVERSION}/${path}"
        fi
    done

    log_message "✅ File structure check completed."
}

# Function to create the package
build_package() {
    log_message "🛠 Building the package (.txz)..."

    # Create the package (.txz), excluding build.sh and build.log files
    pkg create -r "${PKGNAME}-${PKGVERSION}" -m "${PKGNAME}-${PKGVERSION}/+MANIFEST" -p /dev/null -o "${PKGDIR_PATH}" -x "*/build.sh" -x "*/build.log" -x "*/.git"

    log_message "✅ Package created: ${PKGDIR_PATH}/${PKGNAME}-${PKGVERSION}.txz"
}

# Function to populate the repo directory with the built package
populate_repo() {
    log_message "📂 Populating repo directory..."

    # Loop through repos and versions (REPOS now contains repo_name/version format)
    for repo_version in $(echo "$REPOS" | tr -d '"'); do
        # Extract repo and version from repo_version
        repo=$(echo "$repo_version" | cut -d '/' -f1)
        version=$(echo "$repo_version" | cut -d '/' -f2)

        # Loop through architectures
        for arch in $(echo "$ARCHS" | tr -d '"'); do
            # Define the target directory for the package
            target_dir="${REPO_DIR}/${repo}/${version}/${arch}"

            # Create the directory structure for the package
            mkdir -p "${target_dir}"

            # Copy the built package to the correct repo/ directory
            cp "${PKGDIR_PATH}/${PKGNAME}-${PKGVERSION}.txz" "${target_dir}/"

            log_message "✅ Package copied to: ${target_dir}/${PKGNAME}-${PKGVERSION}.txz"
        done
    done
}


# Main script execution
log_message "Starting the build process..."

# Step 1: Check for necessary files and directories
check_file_exists "${MANIFEST_FILE}"

# Step 2: Validate PKGNAME and PKGVERSION in the +MANIFEST file
validate_manifest

# Step 3: Parse the +MANIFEST file to get repo and architecture details
parse_manifest

# Step 4: Check the file structure based on the +MANIFEST file
check_file_structure

# Step 5: Build the package
build_package

# Step 6: Populate the repo directory with the package for each repo/version/architecture
populate_repo

log_message "✅ Build and repo population completed successfully."

