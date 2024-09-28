#!/bin/bash
# -----------------------------------------------------------------------------
# Script to compare JSON keys and check for additions/removals.
#
# Created by: ChatGPT (OpenAI) <https://chatgpt.com/>
# Input provided/Modified by: Caio Oliveira (Caio99BR@GitHub)
# License: MIT License
# -----------------------------------------------------------------------------

# Initialize variables
__NAME="FanControl Json LangControl i18n"
__VERSION="1.3"
update=0
cleanup=0
prettify=0
all=0

# Functions for usage and version
usage() {
    echo "USAGE:"
    echo "  $__NAME [OPTIONS]"
    echo
    echo "  OPTIONS:"
    echo "    -h, --help       Show this help message."
    echo "    -v, --version    Show the version of the script."
    echo "    --update         Add new keys from the base file to translated files."
    echo "    --cleanup        Remove old/unexpected keys from translated files."
    echo "    --prettify       Format JSON files with pretty printing."
    echo "    --all            Include base translation when processing."
}

# Handle command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            return
            ;;
        -v|--version)
            version
            return
            ;;
        --update)
            update=1
            ;;
        --cleanup)
            cleanup=1
            ;;
        --prettify)
            prettify=1
            ;;
        --all)
            all=1
            ;;
        *)
            echo "Unknown option: $1"
            usage
            return 1
            ;;
    esac
    shift
done

version() {
    echo "$__NAME v$__VERSION"
}

# Check for jq or jq-linux-amd64
if command -v jq &> /dev/null; then
    jq_executable="jq"
elif [[ -f "./jq-linux-amd64" ]]; then
    jq_executable="./jq-linux-amd64"
else
    echo "ERROR: jq is not installed or jq-linux-amd64 not found. Please install jq before running this script."
    echo "Available at: https://jqlang.github.io/jq/download/"
    return 1
fi

# Define the base directory as the location of the script
base_dir="$(pwd)"
tmp_dir="$(mktemp -d)/"

# Function to process files
process_files() {
    local base_file="$1"
    local translated_file="$2"

    # Check if the files exist and validate JSON
    if [[ ! -f "$base_file" ]]; then
        echo "ERROR: Base file not found: $base_file"
        return 1
    fi
    if [[ ! -f "$translated_file" ]]; then
        echo "ERROR: Translated file not found: $translated_file"
        return 1
    fi

    # Validate JSON files
    if ! $jq_executable empty "$base_file" &> /dev/null || ! $jq_executable empty "$translated_file" &> /dev/null; then
        echo "ERROR: Invalid JSON in file."
        return 1
    fi

    # Store base keys
    declare -A base_keys
    while IFS= read -r key; do
        base_keys["$key"]=1
    done < <($jq_executable -r 'keys[]' "$base_file")

    # Compare with translated file keys
    declare -A unexpected_keys new_keys
    while IFS= read -r key; do
        if [[ -n "${base_keys[$key]}" ]]; then
            unset "base_keys[$key]"
        else
            unexpected_keys["$key"]=1
        fi
    done < <($jq_executable -r 'keys[]' "$translated_file")

    # Remaining keys in base_keys are new keys
    for key in "${!base_keys[@]}"; do
        new_keys["$key"]=1
    done

    # Display unexpected keys if found
    if [[ ${#unexpected_keys[@]} -gt 0 ]]; then
        echo "- ERROR: UNEXPECTED KEYS ON \"$translated_file\":"
        for key in "${!unexpected_keys[@]}"; do
            echo "$key"
        done
        echo
    fi

    # Display new keys if found
    if [[ ${#new_keys[@]} -gt 0 ]]; then
        echo "+ NEW KEYS TO TRANSLATE ON \"$base_file\":"
        for key in "${!new_keys[@]}"; do
            echo "$key"
        done
        echo
    fi

    # If --update is set, add new keys to the translated file
    if [[ $update -eq 1 ]]; then
        for key in "${!new_keys[@]}"; do
            new_value=$($jq_executable -r ".$key" "$base_file")
            echo "Adding key: $key"
            $jq_executable --arg key "$key" --arg value "$new_value" '. + {($key): $value}' "$translated_file" > "${tmp_dir}translated_file.tmp"
            convert_crlf "${tmp_dir}translated_file.tmp" "$translated_file"
        done
    fi

    # If --cleanup is set, remove unexpected keys
    if [[ $cleanup -eq 1 ]]; then
        for key in "${!unexpected_keys[@]}"; do
            echo "Removing unexpected key: $key"
            $jq_executable "del(.$key)" "$translated_file" > "${tmp_dir}translated_file.tmp"
            convert_crlf "${tmp_dir}translated_file.tmp" "$translated_file"
        done
    fi

    # If --prettify is set, format the JSON files with prettify options
    if [[ $prettify -eq 1 ]]; then
        $jq_executable '.' "$translated_file" > "${tmp_dir}translated_file.tmp"
        if ! diff -q "$translated_file" "${tmp_dir}translated_file.tmp" &> /dev/null; then
            convert_crlf "${tmp_dir}translated_file.tmp" "$translated_file"
            echo "Prettified $translated_file."
        else
            rm "${tmp_dir}translated_file.tmp"
        fi
    fi
}

# Function to convert CRLF to LF
convert_crlf() {
    if grep -q $'\r' "$1"; then
        while IFS= read -r line; do
            echo "$line"
        done < "$1" > "$2"
    else
        mv "$1" "$2"
    fi
}

# Loop through all folders in the base directory
for dir in "$base_dir"/*; do
    if [[ -d "$dir" ]]; then
        base_file="$dir/$(basename "$dir").json"

        # Include base translation file if --all is set
        if [[ $all -eq 1 ]]; then
            process_files "$base_file" "$base_file"
        fi

        for json_file in "$dir"/*.json; do
            if [[ "$(basename "$json_file")" != "$(basename "$base_file")" ]]; then
                process_files "$base_file" "$json_file"
            fi
        done
    fi
done

echo "Done."
