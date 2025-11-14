#!/usr/bin/env bats

# Load the script functions for testing
# We extract just the function definitions without executing main

setup() {
    # Create a temporary version of the script without the main call
    SCRIPT="${BATS_TEST_DIRNAME}/../src/apt-deb822-tool.bash"
    SCRIPT_FUNCS=$(mktemp)
    
    # Extract everything except the last line (main "$@")
    head -n -2 "$SCRIPT" > "$SCRIPT_FUNCS"
    
    # Source the functions
    source "$SCRIPT_FUNCS"
    
    # Set up environment variables that functions expect
    export tmpfile=$(mktemp)
    export file="/tmp/test"
    export verbose=0
    export errors=0
    export write_to_file=0
    export no_backup=0
    export no_null=0
}

teardown() {
    # Clean up temporary files
    rm -f "$tmpfile"
    rm -f "$SCRIPT_FUNCS"
}

# Tests for to_deb822_options function
@test "to_deb822_options: converts 'arch' to 'Architectures'" {
    result=$(to_deb822_options "arch")
    [ "$result" = "Architectures" ]
}

@test "to_deb822_options: converts 'lang' to 'Languages'" {
    result=$(to_deb822_options "lang")
    [ "$result" = "Languages" ]
}

@test "to_deb822_options: converts 'target' to 'Targets'" {
    result=$(to_deb822_options "target")
    [ "$result" = "Targets" ]
}

@test "to_deb822_options: converts 'pdiffs' to 'PDiffs'" {
    result=$(to_deb822_options "pdiffs")
    [ "$result" = "PDiffs" ]
}

@test "to_deb822_options: converts 'inrelease-path' to 'InRelease-Path'" {
    result=$(to_deb822_options "inrelease-path")
    [ "$result" = "InRelease-Path" ]
}

@test "to_deb822_options: converts 'signed-by' to 'Signed-By'" {
    result=$(to_deb822_options "signed-by")
    [ "$result" = "Signed-By" ]
}

@test "to_deb822_options: converts 'by-hash' to 'By-Hash'" {
    result=$(to_deb822_options "by-hash")
    [ "$result" = "By-Hash" ]
}

# Tests for to_apt_list_options function
@test "to_apt_list_options: converts 'Architectures' to 'arch'" {
    result=$(to_apt_list_options "Architectures")
    [ "$result" = "arch" ]
}

@test "to_apt_list_options: converts 'Languages' to 'lang'" {
    result=$(to_apt_list_options "Languages")
    [ "$result" = "lang" ]
}

@test "to_apt_list_options: converts 'Targets' to 'target'" {
    result=$(to_apt_list_options "Targets")
    [ "$result" = "target" ]
}

@test "to_apt_list_options: converts 'Signed-By' to 'signed-by'" {
    result=$(to_apt_list_options "Signed-By")
    [ "$result" = "signed-by" ]
}

@test "to_apt_list_options: converts 'PDiffs' to 'pdiffs'" {
    result=$(to_apt_list_options "PDiffs")
    [ "$result" = "pdiffs" ]
}

# Tests for apt_source_line_to_deb822_line function
@test "apt_source_line_to_deb822_line: converts simple deb line" {
    result=$(apt_source_line_to_deb822_line "deb https://example.com/debian stable main")
    [[ "$result" =~ "Enabled: yes" ]]
    [[ "$result" =~ "Types: deb" ]]
    [[ "$result" =~ "URIs: https://example.com/debian" ]]
    [[ "$result" =~ "Suites: stable" ]]
    [[ "$result" =~ "Components: main" ]]
}

@test "apt_source_line_to_deb822_line: converts disabled deb line" {
    result=$(apt_source_line_to_deb822_line "#deb https://example.com/debian stable main")
    [[ "$result" =~ "Enabled: no" ]]
    [[ "$result" =~ "Types: deb" ]]
}

@test "apt_source_line_to_deb822_line: converts deb-src line" {
    result=$(apt_source_line_to_deb822_line "deb-src https://example.com/debian stable main")
    [[ "$result" =~ "Enabled: yes" ]]
    [[ "$result" =~ "Types: deb-src" ]]
}

@test "apt_source_line_to_deb822_line: converts line with path suite" {
    result=$(apt_source_line_to_deb822_line "deb https://example.com/debian path/")
    [[ "$result" =~ "Suites: path/" ]]
    [[ ! "$result" =~ "Components:" ]]
}

@test "apt_source_line_to_deb822_line: converts line with multiple components" {
    result=$(apt_source_line_to_deb822_line "deb https://example.com/debian stable main contrib non-free")
    [[ "$result" =~ "Components: main contrib non-free" ]]
}

@test "apt_source_line_to_deb822_line: converts line with arch option" {
    result=$(apt_source_line_to_deb822_line "deb [arch=amd64] https://example.com/debian stable main")
    [[ "$result" =~ "Architectures: amd64" ]]
}

@test "apt_source_line_to_deb822_line: converts line with multiple options" {
    result=$(apt_source_line_to_deb822_line "deb [arch=amd64,armhf lang=en,de] https://example.com/debian stable main")
    [[ "$result" =~ "Architectures: amd64 armhf" ]]
    [[ "$result" =~ "Languages: en de" ]]
}

@test "apt_source_line_to_deb822_line: converts line with signed-by option" {
    result=$(apt_source_line_to_deb822_line "deb [signed-by=/usr/share/keyrings/key.asc] https://example.com/debian stable main")
    [[ "$result" =~ "Signed-By: /usr/share/keyrings/key.asc" ]]
}

# Tests for deb822_entry_to_source_lines function
@test "deb822_entry_to_source_lines: converts simple deb822 entry" {
    local entry="Enabled: yes
Types: deb
URIs: https://example.com/debian
Suites: stable
Components: main"
    
    result=$(deb822_entry_to_source_lines "$entry")
    [ "$result" = "deb https://example.com/debian stable main" ]
}

@test "deb822_entry_to_source_lines: converts disabled deb822 entry" {
    local entry="Enabled: no
Types: deb
URIs: https://example.com/debian
Suites: stable
Components: main"
    
    result=$(deb822_entry_to_source_lines "$entry")
    [ "$result" = "#deb https://example.com/debian stable main" ]
}

@test "deb822_entry_to_source_lines: converts deb-src entry" {
    local entry="Enabled: yes
Types: deb-src
URIs: https://example.com/debian
Suites: stable
Components: main"
    
    result=$(deb822_entry_to_source_lines "$entry")
    [ "$result" = "deb-src https://example.com/debian stable main" ]
}

@test "deb822_entry_to_source_lines: converts entry with path suite" {
    local entry="Enabled: yes
Types: deb
URIs: https://example.com/debian
Suites: path/"
    
    result=$(deb822_entry_to_source_lines "$entry")
    [ "$result" = "deb https://example.com/debian path/" ]
}

@test "deb822_entry_to_source_lines: converts entry with multiple components" {
    local entry="Enabled: yes
Types: deb
URIs: https://example.com/debian
Suites: stable
Components: main contrib non-free"
    
    result=$(deb822_entry_to_source_lines "$entry")
    [ "$result" = "deb https://example.com/debian stable main contrib non-free" ]
}

@test "deb822_entry_to_source_lines: converts entry with architectures" {
    local entry="Enabled: yes
Types: deb
URIs: https://example.com/debian
Suites: stable
Components: main
Architectures: amd64 armhf"
    
    result=$(deb822_entry_to_source_lines "$entry")
    [[ "$result" =~ "deb [arch=amd64,armhf] https://example.com/debian stable main" ]]
}

@test "deb822_entry_to_source_lines: converts entry with multiple URIs" {
    local entry="Enabled: yes
Types: deb
URIs: https://example1.com/debian https://example2.com/debian
Suites: stable
Components: main"
    
    result=$(deb822_entry_to_source_lines "$entry")
    [[ "$result" =~ "deb https://example1.com/debian stable main" ]]
    [[ "$result" =~ "deb https://example2.com/debian stable main" ]]
}

@test "deb822_entry_to_source_lines: converts entry with multiple types" {
    local entry="Enabled: yes
Types: deb deb-src
URIs: https://example.com/debian
Suites: stable
Components: main"
    
    result=$(deb822_entry_to_source_lines "$entry")
    [[ "$result" =~ "deb https://example.com/debian stable main" ]]
    [[ "$result" =~ "deb-src https://example.com/debian stable main" ]]
}

@test "deb822_entry_to_source_lines: converts entry with multiple suites" {
    local entry="Enabled: yes
Types: deb
URIs: https://example.com/debian
Suites: stable testing
Components: main"
    
    result=$(deb822_entry_to_source_lines "$entry")
    [[ "$result" =~ "deb https://example.com/debian stable main" ]]
    [[ "$result" =~ "deb https://example.com/debian testing main" ]]
}
