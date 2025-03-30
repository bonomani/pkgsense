#!/bin/bash
# Build script for pfSense package

set -e  # Exit immediately if a command fails

# Log file for the build process
LOG_FILE="build.log"

# Define the log_message function first to avoid "not found" errors
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOG_FILE}"
}

# Full path of the current package directory (define first)
PKGDIR_PATH=$(pwd)
log_message "Full path of the package directory: ${PKGDIR_PATH}"

# Function to get the package name and version dynamically from the current folder
get_package_info() {
    PKGDIR_NAME=$(basename "$PKGDIR_PATH")  # This assumes the current folder is named as "pkgname-version"
    
    # Ensure the folder is in the "pkgname-version" format
    if [[ ! "$PKGDIR_NAME" =~ ^([a-zA-Z0-9_-]+)-([0-9\.]+)$ ]]; then
        log_message "🚨 Folder name must be in the format 'pkgname-version'."
        exit 1
    fi

    PKGNAME=$(echo "$PKGDIR_NAME" | cut -d '-' -f1)
    PKGVERSION=$(echo "$PKGDIR_NAME" | cut -d '-' -f2)
    
    log_message "Detected package name: $PKGNAME"
    log_message "Detected package version: $PKGVERSION"
}

# Get the package name and version
get_package_info

# Define the repo directory and manifest path using the full path
REPO_DIR="${PKGDIR_PATH}/repo"  # Repo directory will be inside the current folder
MANIFEST_FILE="${PKGDIR_PATH}/+MANIFEST"  # Full path to +MANIFEST file

log_message "Looking for +MANIFEST at: ${MANIFEST_FILE}"

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

# Function to recursively check the file structure
check_file_structure_recursive() {
    local parent_path=$1
    local structure=$2

    # Loop through each entry in the structure and check if it's a file or directory
    for key in $(echo "$structure" | jq -r 'keys[]'); do
        local full_path="${parent_path}/${key}"

        # If the value is an array, it's a file
        if [[ "$(echo "$structure" | jq -r ".\"$key\" | type")" == "array" ]]; then
            for file in $(echo "$structure" | jq -r ".\"$key\"[]"); do
                check_file_exists "${PKGDIR_PATH}/${full_path}/${file}"  # Use PKGDIR_PATH for full path
            done
        # If the value is an object, it's a directory, so recurse
        elif [[ "$(echo "$structure" | jq -r ".\"$key\" | type")" == "object" ]]; then
            check_directory_exists "${PKGDIR_PATH}/${full_path}"  # Use PKGDIR_PATH for full path
            check_file_structure_recursive "$full_path" "$(echo "$structure" | jq -r ".\"$key\"")"
        fi
    done
}

# Function to check the file structure based on the +MANIFEST
check_file_structure() {
    log_message "Checking file structure..."

    # Loop through the file structure and handle it based on the new format
    check_file_structure_recursive "" "$file_structure"

    log_message "✅ File structure check completed."
}

# Function to create the package
build_package() {
    log_message "🛠  Building the package (.txz)..."

    # Ensure the repo directory exists and is empty before creating the package
    if [ -d "${REPO_DIR}" ]; then
        log_message "✅ Repo directory exists. Cleaning up old files."
        rm -rf "${REPO_DIR}/*"  # Remove all files in REPO_DIR (but not the directory itself)
    else
        log_message "✅ Repo directory does not exist. Creating it."
        mkdir -p "${REPO_DIR}"  # Create the directory if it doesn't exist
    fi

    # Print the pkg create command with all attributes for debugging
    log_message "Running pkg create with the following command:"
    echo "pkg create -r ${PKGDIR_PATH} -m ${MANIFEST_FILE} -p /dev/null -o ${REPO_DIR} -x '${REPO_DIR}/*' -x '*/build.sh' -x '*/build.log' -x '*/.git'"

    # Run the pkg create command with verbose output and capture both stdout and stderr
    #create_output=$(pkg create -v -r "${PKGDIR_PATH}" -m "${MANIFEST_FILE}" -p /dev/null -o "${REPO_DIR}" -x "${REPO_DIR}/*" -x "*/build.sh" -x "*/build.log" -x "*/.git" 2>&1)
    pkg create -r /tmp/cirrus-ci-build/packages/test-1.0 -m /tmp/cirrus-ci-build/packages/test-1.0/+MANIFEST
    ls -al 
    # Print the output from the pkg create command (including errors)
    log_message "✅ pkg create output:\n$create_output"

    # Debugging: Check if the .txz package exists after creation
    if [ ! -f "${REPO_DIR}/${PKGNAME}-${PKGVERSION}.txz" ]; then
        log_message "🚨 .txz package was not created in the expected location: ${REPO_DIR}/${PKGNAME}-${PKGVERSION}.txz"
        exit 1
    fi

    log_message "✅ Package created: ${REPO_DIR}/${PKGNAME}-${PKGVERSION}.txz"

    # Print the contents of the directory after the package creation
    log_message "Listing contents of the repo directory after creation (${REPO_DIR}):"
    ls -al "${REPO_DIR}"

}

# Function to populate the repo directory with the built package
populate_repo() {
    log_message "📂 Populating repo directory..."

    # Loop through repos and versions (REPOS now contains repo_name/version format)
    for repo_version in $(echo "$REPOS" | tr -d '"'); do
        # Define the target directory for the package using repo/version directly
        target_dir="${REPO_DIR}/${repo_version}"

        log_message "Processing repo/version: $repo_version"

        # Loop through architectures
        for arch in $(echo "$ARCHS" | tr -d '"'); do
            log_message "Processing architecture: $arch"

            # If the architecture is 'any', copy to all supported architectures
            if [[ "$arch" == "any" ]]; then
                for supported_arch in "amd64" "i386" "arm64" "armv7" "powerpc64" "mips64" "aarch64"; do
                    log_message "Copying to supported architecture: $supported_arch"
                    mkdir -p "${target_dir}/${supported_arch}"
                    cp "${REPO_DIR}/${PKGNAME}-${PKGVERSION}.txz" "${target_dir}/${supported_arch}/"
                    log_message "✅ Package copied to: ${target_dir}/${supported_arch}/${PKGNAME}-${PKGVERSION}.txz"
                done
            else
                # Handle the specified architecture (if not 'any')
                mkdir -p "${target_dir}/${arch}"
                cp "${REPO_DIR}/${PKGNAME}-${PKGVERSION}.txz" "${target_dir}/${arch}/"
                log_message "✅ Package copied to: ${target_dir}/${arch}/${PKGNAME}-${PKGVERSION}.txz"
            fi
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

