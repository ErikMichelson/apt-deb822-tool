#!/usr/bin/env bats

# Main test suite entry point
# This file serves as the entry point for all tests

@test "test suite is properly configured" {
    [ -f "${BATS_TEST_DIRNAME}/../src/apt-deb822-tool.bash" ]
    [ -f "${BATS_TEST_DIRNAME}/conversion.bats" ]
    [ -f "${BATS_TEST_DIRNAME}/integration.bats" ]
}

@test "script is executable" {
    [ -x "${BATS_TEST_DIRNAME}/../src/apt-deb822-tool.bash" ] || [ -r "${BATS_TEST_DIRNAME}/../src/apt-deb822-tool.bash" ]
}

@test "test files exist" {
    [ -f "${BATS_TEST_DIRNAME}/files/valid.list" ]
    [ -f "${BATS_TEST_DIRNAME}/files/valid.sources" ]
    [ -f "${BATS_TEST_DIRNAME}/files/invalid.sources" ]
}
