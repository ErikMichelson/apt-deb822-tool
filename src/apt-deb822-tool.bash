#!/usr/bin/env bash
set -euo pipefail

PROGNAME="apt-deb822-tool"
VERSION="1.0"
REPO_URL="https://github.com/ErikMichelson/apt-deb822-tool"

# Capitalizes a string with words separated by '-'
#
# Arguments:
#   $1: The string to capitalize
# Output:
#   The capitalized string
# Example: capitalize_options "signed-by" -> "Signed-By", capitalize_options "arch" -> "Arch"
capitalize_options () {
    local words
    IFS='-' read -ra words <<< "${1}"
    for i in "${!words[@]}"; do
        words[i]="${words[$i]^}"
    done
    echo "${words[*]}" | tr ' ' '-'
}

# Lowercases a string with words separated by '-'
#
# Arguments:
#   $1: The string to lowercase
# Output:
#   The lowercased string
# Example: lowercase_options "Signed-By" -> "signed-by", lowercase_options "Arch" -> "arch"
lowercase_options () {
    local words
    IFS='-' read -ra words <<< "${1}"
    for i in "${!words[@]}"; do
        words[i]="${words[$i],,}"
    done
    echo "${words[*]}" | tr ' ' '-'
}

# Converts an apt source line to deb822 format
#
# Arguments:
#   $1: The line to convert
# Output:
#   The deb822 formatted entry
apt_source_line_to_deb822_line () {
    local line="$1"
                
    # Split by spaces
    local fields
    IFS=' ' read -ra fields <<< "${line}"

    local current_step=0 # 0: type, 1: options, 2: uri, 3: suites, 4: components
    declare -A options=()
    local in_options=0
    local suites_is_path=0

    for field in "${fields[@]}"; do
        if [[ -z "${field}" ]]; then
            continue
        fi

        # Parse type and enabled status
        local enabled
        if [[ ${current_step} -eq 0 ]]; then
            if [[ "${field}" == "#"* ]]; then
                field="${field:1}"
                enabled=no
            else
                enabled=yes
            fi
            local type="${field}"
            current_step=1
            continue
        fi

        # Check for comment
        if [[ "${field}" == "#"* ]]; then
            break
        fi

        # Check if options present
        if [[ ${current_step} -eq 1 ]]; then
            if [[ "${field}" == "["* ]]; then
                in_options=1
                field="${field:1}"
            fi
        fi

        # Detect end of options
        if [[ "${field}" == "]"* ]]; then
            in_options=0
            current_step=2
            continue
        fi

        # Parse options
        if [[ ${in_options} -eq 1 ]]; then

            # Check if being the last option
            if [[ "${field}" == *"]" ]]; then
                field="${field%?}"
                in_options=0
                current_step=2
            fi

            local key
            local values

            # Syntax for appending values to an option
            if [[ "${field}" == *"+="* ]]; then
                key=$(echo "${field}" | cut -d'+=' -f1)
                values=$(echo "${field}" | cut -d'+=' -f2 | tr ',' ' ')
                if [[ -n "${options[${key}]}" ]]; then
                    options[${key}]="${options[${key}]} ${values}"
                else
                    options[${key}]="${values}"
                fi

            # Syntax for removing values from an option
            elif [[ "${field}" == *"-="* ]]; then
                key=$(echo "${field}" | cut -d'-=' -f1)
                values=$(echo "${field}" | cut -d'-=' -f2)
                local values_arr
                IFS=',' read -ra values_arr <<< "${values}"
                if [[ -n "${options[${key}]}" ]]; then
                    for value in "${values_arr[@]}"; do
                        options[${key}]=${options[${key}]//${value}/}
                    done
                fi

            # Syntax for setting values to an option
            elif [[ "${field}" == *"="* ]]; then
                key=$(echo "${field}" | cut -d'=' -f1)
                values=$(echo "${field}" | cut -d'=' -f2 | tr ',' ' ')
                options[${key}]="${values}"
            else
                log_warn "Invalid option detected: ${field}"
            fi

            continue
        fi

        # Parse uri
        if [[ ${current_step} -eq 2 ]]; then
            local uri="${field}"
            current_step=3
            continue
        fi

        # Parse suites
        if [[ ${current_step} -eq 3 ]]; then
            if [[ "${field}" == */* ]]; then
                suites_is_path=1
            fi
            local suites="${field}"
            current_step=4
            continue
        fi

        # Parse components
        local components
        if [[ ${current_step} -eq 4 ]]; then
            if [[ ${suites_is_path} -eq 1 ]]; then
                log_warn "Invalid entry encountered: Suites is a path, skipping components"
            else
                components+="${field}"
            fi
        fi
    done

    # Convert options to deb822 format
    local deb822_options=""
    for key in "${!options[@]}"; do
        local value="${options[${key}]}"
        key=$(capitalize_options "${key}")
        deb822_options+="${key}: ${value}\n"
    done

    # Convert the entry to deb822 format
    local deb822
    deb822=$(printf "Enabled: %s\nTypes: %s\nURIs: %s\nSuites: %s" "${enabled}" "${type}" "${uri}" "${suites}")
    if [[ ${suites_is_path} -eq 0 ]]; then
        deb822+="\nComponents: ${components}"
    fi
    deb822+="\n${deb822_options}"

    # Return the deb822 formatted entry
    echo "${deb822}"
}

# Converts a deb822 entry to apt source lines
#
# Arguments:
#   $1: The entry to convert
# Output:
#   The converted file if not writing to file
deb822_entry_to_source_lines () {
    local entry="$1"

    local entry_enabled=0
    local entry_types=""
    local entry_uris=""
    local entry_suites=""
    local entry_components=""
    declare -A entry_options

    entry=$(echo -e "${entry}")

    if [[ -z "${entry}" ]]; then
        log_verbose "Skipping empty entry"
        return
    fi

    local lines
    IFS=$'\n' read -d '' -ra lines <<< "${entry}"

    for line in "${lines[@]}"; do
        # Skip empty lines
        if [[ -z "${line}" ]]; then
            continue
        fi

        # Skip comments
        if [[ "${line}" =~ ^"#" ]]; then
            echo "${line}" >> "${tmpfile}"
            continue
        fi

        # Split by colon
        local entry_key
        local entry_value
        entry_key=$(echo "${line}" | cut -d':' -f1 | tr -d '[:space:]')
        entry_value=$(echo "${line}" | cut -d':' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        # Parse entry
        case "${entry_key}" in
            Enabled)
                if [[ "${entry_value}" == "yes" ]]; then
                    entry_enabled=1
                elif [[ "${entry_value}" == "no" ]]; then
                    entry_enabled=0
                else
                    log_err "Invalid value for key \"Enabled\" in file ${file}"
                    return 1
                fi
                ;;
            Types)
                entry_types="${entry_value}"
                ;;
            URIs)
                entry_uris="${entry_value}"
                ;;
            Suites)
                entry_suites="${entry_value}"
                ;;
            Components)
                entry_components="${entry_value}"
                ;;
            *)
                entry_options[$(lowercase_options "${entry_key}")]="${entry_value}"
                ;;
        esac
    done

    # Check if all required fields are present
    if [[ -z "${entry_types}" ]]; then
        log_err "Missing required field \"Types\" in file ${file}"
        return 1
    fi

    if [[ -z "${entry_uris}" ]]; then
        log_err "Missing required field \"URIs\" in file ${file}"
        return 1
    fi

    if [[ -z "${entry_suites}" ]]; then
        log_err "Missing required field \"Suites\" in file ${file}"
        return 1
    fi

    if [[ -z "${entry_components}" ]] && [[ "${entry_suites}" == */* ]]; then
        log_err "Missing required field \"Components\" in file ${file}"
        return 1
    fi

    # Convert the entry to apt-list format
    entry_uris_arr=()
    IFS=' ' read -ra entry_uris_arr <<< "${entry_uris}"

    entry_suites_arr=()
    IFS=' ' read -ra entry_suites_arr <<< "${entry_suites}"

    entry_types_arr=()
    IFS=' ' read -ra entry_types_arr <<< "${entry_types}"

    local apt_list_entries=()

    # Deb822 format allows multiple URIs, Suites and Types per entry
    # This results in multiple apt-list entries per deb822 entry
    for uri in "${entry_uris_arr[@]}"; do
        for suite in "${entry_suites_arr[@]}"; do
            for type in "${entry_types_arr[@]}"; do
                local apt_list_entry
                if [[ ${entry_enabled} -eq 0 ]]; then
                    apt_list_entry+="#"
                fi
                apt_list_entry+="${type}"
                if [[ ${#entry_options[@]} -gt 0 ]]; then
                    apt_list_entry+=" ["
                    for key in "${!entry_options[@]}"; do
                        apt_list_entry+="${key}="
                        apt_list_entry+="${entry_options[${key}]}"
                        apt_list_entry+=" "
                    done
                    apt_list_entry+="]"
                fi
                apt_list_entry+=" ${uri} ${suite}"
                if [[ "${suite}" != */* ]]; then
                    apt_list_entry+=" ${entry_components}"
                fi
                apt_list_entries+=("${apt_list_entry}")
            done
        done
    done

    # Return the apt-list formatted entries
    log_verbose "Created ${#apt_list_entries[@]} apt-list entries for Deb822 entry"
    echo "${apt_list_entries[@]}"
}

# Converts a file in apt-list format to deb822 format
#
# Arguments:
#   $1: The file to convert
# Output:
#   The converted file if not writing to file
to_deb822 () {
    local file="$1"
    local tmpfile
    tmpfile=$(mktemp)

    while IFS= read -r line; do
        # Skip empty lines
        if [[ -z "${line}" ]]; then
            continue
        fi

        # Only operate on lines with deb or deb-src prefixes (include disabled entries)
        if [[ ${line} =~ ^(deb|#deb|deb-src|#deb-src) ]]; then
            local deb822
            deb822=$(apt_source_line_to_deb822_line "${line}")
            if [[ $? -ne 0 ]]; then
                log_verbose "There were errors while converting an entry from ${file}"
                errors=1
            fi
            echo -e "${deb822}\n" >> "${tmpfile}"
        else
            # Copy comments as is
            if [[ "${line}" =~ ^"#" ]]; then
                echo "${line}" >> "${tmpfile}"
                continue
            fi
            
            # Unrecognized line, copy it as a comment
            echo "# ${line}" >> "${tmpfile}"
        fi
    done < "${file}"

    new_file_name="${file%.list.distUpgrade}"
    new_file_name="${new_file_name%.list}"
    new_file_name="${new_file_name}.sources"

    write_output_files "${tmpfile}" "${file}" "${new_file_name}"
}

# Converts a file in deb822 format to apt-list format
#
# Arguments:
#   $1: The file to convert
# Output:
#   The converted file if not writing to file
to_list () {
    local file="$1"
    local tmpfile
    tmpfile=$(mktemp)

    local entries=()
    local current_entry=""

    while IFS= read -r line; do
        # Split entries on empty lines
        if [[ -z "${line}" ]]; then
            entries+=( "${current_entry}" )
            current_entry=""
            continue
        fi

        current_entry+="${line}\n"
    done < "${file}"

    entries+=( "${current_entry}" )

    for entry in "${entries[@]}"; do
        local apt_source_lines
        apt_source_lines=$(deb822_entry_to_source_lines "${entry}")
        if [[ $? -ne 0 ]]; then
            log_verbose "There were errors while converting an entry from ${file}"
            errors=1
        fi
        echo -e "${apt_source_lines}\n" >> "${tmpfile}"
    done

    write_output_files "${tmpfile}" "${file}" "${file%.sources}.list"
}

# Writes the output files or prints to STDOUT
#
# Arguments:
#   $1: The temporary file to write
#   $2: The original file to replace
#   $3: The new file name
write_output_files () {
    local tmpfile="$1"
    local file="$2"
    local new_file_name="$3"

    if [[ ${write_to_file} -eq 1 ]]; then
        # Create backup if not disabled
        if [[ ${no_backup} -eq 0 ]]; then
            mv "${file}" "${file}.bak"
        else
            rm -f "${file}" || log_warn "Failed to remove original file: ${file}"
        fi
        mv "${tmpfile}" "${new_file_name}"
    else
        cat "${tmpfile}"
        if [[ ${no_null} -eq 0 ]]; then
            echo -ne "\0"
        fi
        rm -f "${tmpfile}" || log_warn "Failed to remove temporary file: ${tmpfile}"
    fi
}

# Reads STDIN to a temporary file for operating on it
#
# Output:
#   The path to the temporary file
read_stdin_to_tempfile () {
    local tmpfile
    tmpfile=$(mktemp)
    cat /dev/stdin > "${tmpfile}"
    echo "${tmpfile}"
}

# Shows the help message
show_help () {
    show_version
    echo ""
    echo "Usage: $0 <to-deb822|to-list> [OPTIONS] <file1> [file2 dir1 dir2...]"
    echo "Converts apt sources.list files to deb822 format (.sources files) or vice versa"
    echo
    echo "Per default this tool converts all given files to the other format on STDOUT."
    echo "Use a single dash (-) instead of files to read from STDIN."
    echo "When a directory is given, only files with the matching extension will be converted."
    echo "This can be overridden with the --all-extensions option."
    echo
    echo "Modes: "
    echo "  to-deb822   Use this mode to convert apt sources.list files to deb822 format"
    echo "  to-list     Use this mode to convert deb822 format (.sources files) to apt sources.list files"
    echo
    echo "Options:"
    echo "  -A, --all-extensions  Convert all files in the specified directories"
    echo "  -W, --write           Instead of printing to STDOUT, write the output to the file"
    echo "  -v, --verbose         Show more detailed output information"
    echo "  --no-backup           Do not backup the original files"
    echo "  --no-null             Do not print a null byte after each file on STDOUT output (does nothing when --write is set)"
    echo
    echo "  --help                Show this help message"
    echo "  -V, --version         Show version information"
    echo
}

# Shows the version information
show_version () {
    echo "${PROGNAME} ${VERSION}"
    echo "${REPO_URL}"
}

# Global error flag
errors=0

# Logs an error message and sets the error flag
#
# Arguments:
#   $1: The error message to log
log_err () {
    errors=1
    echo "ERROR: $1" 1>&2
}

# Logs a warning message
#
# Arguments:
#   $1: The warning message to log
log_warn () {
    echo "WARNING: $1" 1>&2
}

# Logs a verbose message if verbose logging is enabled
#
# Arguments:
#   $1: The verbose message to log
log_verbose () {
    if [[ ${verbose} -eq 1 ]]; then
        echo "VERBOSE: $1" 1>&2
    fi
}

# Main entrypoint, argument parsing and dispatching
main () {
    local mode=0 # 0: unset, 1: list-to-deb822, 2: deb822-to-list

    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi

    # Prepare CLI options
    all_extensions=0
    write_to_file=0
    no_backup=0
    no_null=0
    verbose=0

    local cli_options=()
    local inputs=()
    local options_parsed=0

    for arg in "$@"; do
        # As long as no mode is selected, only allow modes or CLI options
        if [[ "${mode}" -eq 0 ]]; then
            if [[ "${arg}" == "to-deb822" ]]; then
                mode=1
            elif [[ "${arg}" == "to-list" ]]; then
                mode=2
            else
                if [[ "${arg}" == "-"* ]]; then
                    cli_options+=( "${arg}" )
                else
                    log_err "Unknown argument given. Expected mode or options."
                    exit 1
                fi
            fi
            continue
        fi

        # -- is indicating that no CLI options follow anymore
        if [[ "${arg}" == "--" ]]; then
            options_parsed=1
            continue
        fi

        # A single dash indicates that the input is read from STDIN, no CLI options or paths can follow
        if [[ "${arg}" == "-" ]] && [[ "${options_parsed}" -eq 0 ]]; then
            inputs=( "-" )
            break
        fi

        # As long as cli_options aren't finished yet, add them to the CLI options array
        if [[ "${arg}" == "-"* ]] && [[ "${options_parsed}" -eq 0 ]]; then
            cli_options+=( "${arg}" )
            continue
        fi

        # Everything else is considered the list of input files/dirs
        inputs+=( "${arg}" )

        # When the first argument is not an option, the CLI options are considered parsed
        options_parsed=1
    done

    for option in "${cli_options[@]}"; do
        case "${option}" in
            -A|--all-extensions)
                all_extensions=1
                ;;
            -W|--write)
                write_to_file=1
                ;;
            -v|--verbose)
                verbose=1
                log_verbose "Verbose logging enabled"
                ;;
            --no-backup)
                no_backup=1
                ;;
            --no-null)
                no_null=1
                ;;
            --help)
                show_help
                exit 0
                ;;
            -V|--version)
                show_version
                exit 0
                ;;
            *)
                log_err "Unknown option given: ${option}"
                exit 1
                ;;
        esac
    done

    if [[ ${mode} -eq 0 ]]; then
        log_err "No mode selected. Please specify either 'to-deb822' or 'to-list'."
        exit 1
    fi

    if [[ ${#inputs[@]} -eq 0 ]]; then
        log_err "No input files or directories given."
        exit 1
    fi

    local files=()
    local remove_files=()

    for input in "${inputs[@]}"; do
        # Add STDIN as temp file
        if [[ "${input}" == "-" ]]; then
            if [[ ${write_to_file} -eq 1 ]]; then
                log_warn "Ignoring --write option when reading from STDIN"
                write_to_file=0
            fi
            log_verbose "Reading from STDIN"
            local tmpfile
            tmpfile=$(read_stdin_to_tempfile)
            files=( "${tmpfile}" )
            remove_files+=( "${tmpfile}" )
        # Traverse files in directory (optionally with extension matching)
        elif [[ -d "${input}" ]]; then
            local dir_files=()
            if [[ ${all_extensions} -eq 1 ]]; then
                mapfile -t dir_files < <(find "${input}" -type f)
            else
                if [[ ${mode} -eq 1 ]]; then
                    mapfile -t dir_files < <(find "${input}" -type f \( -name '*.list' -o -name '*.list.distUpgrade' \))
                elif [[ ${mode} -eq 2 ]]; then
                    mapfile -t dir_files < <(find "${input}" -type f -name '*.sources')
                fi
            fi
            files+=( "${dir_files[@]}" )
        # Add normal files
        elif [[ -f "${input}" ]]; then
            files+=( "${input}" )
        # File not found
        else
            log_err "File or directory not found: ${input}"
        fi
    done

    for file in "${files[@]}"; do
        if [[ ${verbose} -eq 1 ]]; then
            log_verbose "Converting file: ${file}"
        fi
        if [[ ${mode} -eq 1 ]]; then
            to_deb822 "${file}"
        elif [[ ${mode} -eq 2 ]]; then
            to_list "${file}"
        fi
    done

    # Cleanup temporary files
    for file in "${remove_files[@]}"; do
        rm -f "${file}" || log_warn "Failed to remove temporary file: ${file}"
    done

    if [[ ${errors} -eq 1 ]]; then
        exit 1
    fi
}

# Pass all arguments to main
main "$@"
