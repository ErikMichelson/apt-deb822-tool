#!/usr/bin/env bats

# Integration tests for full file conversion
SCRIPT="${BATS_TEST_DIRNAME}/../src/apt-deb822-tool.bash"
TEST_FILES="${BATS_TEST_DIRNAME}/files"

setup() {
    # Create a temporary directory for test output
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_TEMP_DIR"
}

# Test to-deb822 conversion
@test "to-deb822: converts valid.list to deb822 format" {
    run bash "$SCRIPT" to-deb822 "$TEST_FILES/valid.list"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Enabled: yes" ]]
    [[ "$output" =~ "Types: deb" ]]
    [[ "$output" =~ "URIs: https://valid.example.com/debian" ]]
    [[ "$output" =~ "Suites: all" ]]
    [[ "$output" =~ "Components: main" ]]
}

@test "to-deb822: converts disabled entry correctly" {
    run bash "$SCRIPT" to-deb822 "$TEST_FILES/valid.list"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Enabled: no" ]]
}

@test "to-deb822: converts path suite correctly" {
    run bash "$SCRIPT" to-deb822 "$TEST_FILES/valid.list"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Suites: path/" ]]
}

@test "to-deb822: converts options correctly" {
    run bash "$SCRIPT" to-deb822 "$TEST_FILES/valid.list"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Signed-By: /usr/share/keyrings/example.asc" ]]
    [[ "$output" =~ "Languages: en de fr it" ]]
    [[ "$output" =~ "Architectures: amd64 armhf" ]]
}

@test "to-deb822: preserves comments" {
    run bash "$SCRIPT" to-deb822 "$TEST_FILES/valid.list"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "# Comments are ignored" ]]
}

# Test to-list conversion
@test "to-list: converts valid.sources to list format" {
    run bash "$SCRIPT" to-list "$TEST_FILES/valid.sources"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "deb https://valid.example.com/debian all main" ]]
}

@test "to-list: converts disabled entry correctly" {
    run bash "$SCRIPT" to-list --no-null "$TEST_FILES/valid.sources"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "#deb" ]]
    [[ "$output" =~ "signed-by=/usr/share/keyrings/example.asc" ]]
}

@test "to-list: converts deb-src correctly" {
    run bash "$SCRIPT" to-list "$TEST_FILES/valid.sources"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "deb-src https://valid.example.com/debian path/" ]]
}

@test "to-list: converts path suite correctly" {
    run bash "$SCRIPT" to-list "$TEST_FILES/valid.sources"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "deb-src https://valid.example.com/debian path/" ]]
    # Check that path suite doesn't have components
    run bash "$SCRIPT" to-list "$TEST_FILES/valid.sources"
    [[ ! "$output" =~ "deb-src https://valid.example.com/debian path/ main" ]]
}

@test "to-list: converts options correctly" {
    run bash "$SCRIPT" to-list "$TEST_FILES/valid.sources"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "signed-by=/usr/share/keyrings/example.asc" ]]
    [[ "$output" =~ "lang=en,de,fr,it" ]]
    [[ "$output" =~ "arch=amd64,armhf" ]]
}

# Test error handling
@test "to-list: reports error for invalid Enabled value" {
    run bash "$SCRIPT" to-list "$TEST_FILES/invalid.sources"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR" ]]
}

@test "to-list: reports error for missing URIs field" {
    run bash "$SCRIPT" to-list "$TEST_FILES/invalid.sources"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR" ]]
}

@test "to-list: reports error for components with path suite" {
    run bash "$SCRIPT" to-list "$TEST_FILES/invalid.sources"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "ERROR" ]]
}

# Test round-trip conversion
@test "round-trip: list -> deb822 -> list produces similar output" {
    # Convert list to deb822
    deb822_output=$(bash "$SCRIPT" to-deb822 "$TEST_FILES/valid.list")
    
    # Write to temp file
    echo "$deb822_output" > "$TEST_TEMP_DIR/temp.sources"
    
    # Convert back to list
    list_output=$(bash "$SCRIPT" to-list "$TEST_TEMP_DIR/temp.sources")
    
    # Check that output contains expected lines
    [[ "$list_output" =~ "deb https://valid.example.com/debian all main" ]]
    [[ "$list_output" =~ "deb-src https://valid.example.com/debian path/" ]]
}

@test "round-trip: deb822 -> list -> deb822 produces similar output" {
    # Convert deb822 to list
    list_output=$(bash "$SCRIPT" to-list "$TEST_FILES/valid.sources")
    
    # Write to temp file
    echo "$list_output" > "$TEST_TEMP_DIR/temp.list"
    
    # Convert back to deb822
    deb822_output=$(bash "$SCRIPT" to-deb822 "$TEST_TEMP_DIR/temp.list")
    
    # Check that output contains expected fields
    [[ "$deb822_output" =~ "Enabled: yes" ]]
    [[ "$deb822_output" =~ "Types: deb" ]]
    [[ "$deb822_output" =~ "URIs: https://valid.example.com/debian" ]]
}

# Test CLI options
@test "shows help when no arguments provided" {
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "shows help with --help flag" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "shows version with --version flag" {
    run bash "$SCRIPT" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "apt-deb822-tool" ]]
}

@test "shows version with -V flag" {
    run bash "$SCRIPT" -V
    [ "$status" -eq 0 ]
    [[ "$output" =~ "apt-deb822-tool" ]]
}

@test "verbose mode produces verbose output" {
    run bash "$SCRIPT" to-deb822 --verbose "$TEST_FILES/valid.list"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "VERBOSE:" ]]
}

@test "requires mode to be specified" {
    run bash "$SCRIPT" "$TEST_FILES/valid.list"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown argument given" ]] || [[ "$output" =~ "No mode selected" ]]
}

@test "requires input files to be specified" {
    run bash "$SCRIPT" to-deb822
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No input files or directories given" ]]
}

# Test write mode
@test "write mode creates output file" {
    # Copy test file to temp directory
    cp "$TEST_FILES/valid.list" "$TEST_TEMP_DIR/test.list"
    
    # Convert with write mode
    run bash "$SCRIPT" to-deb822 --write "$TEST_TEMP_DIR/test.list"
    [ "$status" -eq 0 ]
    
    # Check that .sources file was created
    [ -f "$TEST_TEMP_DIR/test.sources" ]
    
    # Check that backup was created
    [ -f "$TEST_TEMP_DIR/test.list.bak" ]
}

@test "write mode with --no-backup doesn't create backup" {
    # Copy test file to temp directory
    cp "$TEST_FILES/valid.list" "$TEST_TEMP_DIR/test.list"
    
    # Convert with write mode and no backup
    run bash "$SCRIPT" to-deb822 --write --no-backup "$TEST_TEMP_DIR/test.list"
    [ "$status" -eq 0 ]
    
    # Check that .sources file was created
    [ -f "$TEST_TEMP_DIR/test.sources" ]
    
    # Check that backup was NOT created
    [ ! -f "$TEST_TEMP_DIR/test.list.bak" ]
}

# Test directory processing
@test "processes directory with matching extensions" {
    run bash "$SCRIPT" to-deb822 "$TEST_FILES"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Enabled: yes" ]]
}

@test "processes directory recursively" {
    # Create subdirectory with test file
    mkdir -p "$TEST_TEMP_DIR/subdir"
    cp "$TEST_FILES/valid.list" "$TEST_TEMP_DIR/subdir/test.list"
    
    run bash "$SCRIPT" to-deb822 "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Enabled: yes" ]]
}
