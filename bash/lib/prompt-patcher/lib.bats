#!/usr/bin/env bats
# Tests for bash/lib/prompt-patcher/lib.bash

# Load bats helper libraries
bats_require_minimum_version 1.5.0
load '/usr/lib/bats/bats-support/load.bash'
load '/usr/lib/bats/bats-assert/load.bash'
load '/usr/lib/bats/bats-file/load.bash'

# Setup/teardown helpers
setup() {
    # Load the library under test
    source "$BATS_TEST_DIRNAME/lib.bash"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(temp_make)"
    TEST_FILE="$TEST_TEMP_DIR/TEST_PROMPT.md"
}

teardown() {
    # Cleanup temp directory
    temp_del "$TEST_TEMP_DIR"
}

count_trailing_newlines() {
    local file="$1"
    # Get last 20 bytes and count newlines at end
    tail -c 20 "$file" | od -An -c | grep -o '\\n' | wc -l
}

@test "insert_or_replace_block inserts block into empty file" {
    echo "# Test Header" > "$TEST_FILE"

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success

    # Verify block markers exist
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: sandbox-bwrap -->"
    assert_file_contains "$TEST_FILE" "<!-- END-SANDBOX-BLOCK: sandbox-bwrap -->"
}

@test "insert_or_replace_block is idempotent - no newline accumulation" {
    echo "# Test Header" > "$TEST_FILE"

    # Insert block three times
    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success
    size_after_first=$(wc -c < "$TEST_FILE")

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success
    size_after_second=$(wc -c < "$TEST_FILE")

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success
    size_after_third=$(wc -c < "$TEST_FILE")

    # File size should be identical after each operation
    assert_equal "$size_after_first" "$size_after_second"
    assert_equal "$size_after_second" "$size_after_third"
}

@test "insert_or_replace_block replaces existing block" {
    echo "# Test Header" > "$TEST_FILE"

    # Insert initial block
    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success

    # Verify only one occurrence of start marker
    run bash -c "grep -c '<!-- SANDBOX-BLOCK: sandbox-bwrap -->' '$TEST_FILE'"
    assert_output "1"

    # Replace block
    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success

    # Should still have exactly one occurrence
    run bash -c "grep -c '<!-- SANDBOX-BLOCK: sandbox-bwrap -->' '$TEST_FILE'"
    assert_output "1"
}

@test "remove_prompt_block removes block completely" {
    echo "# Test Header" > "$TEST_FILE"

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success

    # Verify block exists
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: sandbox-bwrap -->"

    run remove_prompt_block "$TEST_FILE" "sandbox-bwrap"
    assert_success

    # Verify block is gone
    assert_file_not_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: sandbox-bwrap -->"
    assert_file_not_contains "$TEST_FILE" "<!-- END-SANDBOX-BLOCK: sandbox-bwrap -->"
}

@test "replace_all_prompt_blocks handles multiple blocks" {
    echo "# Test Header" > "$TEST_FILE"

    run replace_all_prompt_blocks "$TEST_FILE" "" "sandbox-bwrap" "git-readonly"
    assert_success

    # Both blocks should exist
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: sandbox-bwrap -->"
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: git-readonly -->"
}

@test "replace_all_prompt_blocks removes obsolete blocks" {
    echo "# Test Header" > "$TEST_FILE"

    # Add three blocks
    run replace_all_prompt_blocks "$TEST_FILE" "" "sandbox-bwrap" "git-readonly" "sandbox-vm"
    assert_success

    # Verify all three exist
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: sandbox-bwrap -->"
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: git-readonly -->"
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: sandbox-vm -->"

    # Replace with only two blocks
    run replace_all_prompt_blocks "$TEST_FILE" "" "sandbox-bwrap" "git-readonly"
    assert_success

    # First two should exist, third should be removed
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: sandbox-bwrap -->"
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: git-readonly -->"
    assert_file_not_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: sandbox-vm -->"
}

@test "get_existing_block_ids returns correct block IDs" {
    echo "# Test Header" > "$TEST_FILE"

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success
    run insert_or_replace_block "$TEST_FILE" "git-readonly"
    assert_success

    run get_existing_block_ids "$TEST_FILE"
    assert_success
    assert_line --partial "sandbox-bwrap"
    assert_line --partial "git-readonly"
}

@test "get_prompt_filename returns correct filenames" {
    run get_prompt_filename claude
    assert_success
    assert_output "CLAUDE.md"

    run get_prompt_filename gemini
    assert_success
    assert_output "GEMINI.md"

    run get_prompt_filename opencode
    assert_success
    assert_output "AGENT.md"
}

@test "get_prompt_filename fails for unknown tool" {
    run get_prompt_filename "unknown-tool"
    assert_failure
    assert_output --partial "Unknown tool"
}

@test "get_prompt_block injects allowlist for proxy-restrictions" {
    # Create test allowlist
    local allowlist="$TEST_TEMP_DIR/allowlist.txt"
    cat > "$allowlist" <<EOF
# Comment line
^example\.com$
^.*\.github\.com$

^api\.service\.net$
EOF

    run get_prompt_block "proxy-restrictions" "$allowlist"
    assert_success

    # Should contain formatted domains (without regex syntax)
    assert_output --partial "example.com"
    assert_output --partial "*github.com"
    assert_output --partial "api.service.net"

    # Should NOT contain comment lines
    refute_output --partial "# Comment"
}

@test "get_prompt_block fails for non-existent block" {
    run get_prompt_block "non-existent-block"
    assert_failure
    assert_output --partial "Block not found"
}

@test "remove_prompt_block safely handles non-existent block" {
    echo "# Test Header" > "$TEST_FILE"

    # Should not error
    run remove_prompt_block "$TEST_FILE" "non-existent-block"
    assert_success
}

@test "operations on non-existent file are safe" {
    local missing_file="$TEST_TEMP_DIR/missing.md"

    run remove_prompt_block "$missing_file" "sandbox-bwrap"
    assert_success

    run get_existing_block_ids "$missing_file"
    assert_success
}

@test "insert_or_replace_block preserves file permissions" {
    echo "# Test Header" > "$TEST_FILE"
    chmod 600 "$TEST_FILE"

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success

    # Check permissions are still 600
    run stat -c "%a" "$TEST_FILE"
    assert_output "600"
}

@test "get_prompt_block output includes start and end markers" {
    run get_prompt_block "sandbox-bwrap"
    assert_success

    # First line should be start marker
    assert_line --index 0 "<!-- SANDBOX-BLOCK: sandbox-bwrap -->"

    # Last line should be end marker
    last_line=$(get_prompt_block 'sandbox-bwrap' | tail -1)
    assert_equal "$last_line" "<!-- END-SANDBOX-BLOCK: sandbox-bwrap -->"
}

@test "format_allowlist_for_prompt handles missing allowlist gracefully" {
    run format_allowlist_for_prompt "/nonexistent/allowlist.txt"
    assert_success
    assert_output ""
}

@test "multiple insert operations do not duplicate block content" {
    echo "# Original Content" > "$TEST_FILE"

    # Insert same block multiple times
    for i in {1..3}; do
        run insert_or_replace_block "$TEST_FILE" "git-readonly"
        assert_success
    done

    # Should have exactly one start and one end marker
    run bash -c "grep -c '<!-- SANDBOX-BLOCK: git-readonly -->' '$TEST_FILE'"
    assert_output "1"

    run bash -c "grep -c '<!-- END-SANDBOX-BLOCK: git-readonly -->' '$TEST_FILE'"
    assert_output "1"
}

@test "replace_all_prompt_blocks automatically includes default blocks" {
    echo "# Test Header" > "$TEST_FILE"

    # Call with only environment-specific blocks
    run replace_all_prompt_blocks "$TEST_FILE" "" "sandbox-bwrap"
    assert_success

    # Default blocks should be automatically included
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: communication -->"
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: conventions -->"

    # Requested block should also be present
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: sandbox-bwrap -->"
}

@test "replace_all_prompt_blocks includes only default blocks when no others specified" {
    echo "# Test Header" > "$TEST_FILE"

    # Call with no environment-specific blocks
    run replace_all_prompt_blocks "$TEST_FILE" ""
    assert_success

    # Default blocks should still be included
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: communication -->"
    assert_file_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: conventions -->"

    # No other blocks should be present
    assert_file_not_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: sandbox-bwrap -->"
    assert_file_not_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: git-readonly -->"
}
