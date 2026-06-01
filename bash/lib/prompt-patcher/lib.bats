#!/usr/bin/env bats
# Tests for bash/lib/prompt-patcher/lib.bash

# Load bats helper libraries
bats_require_minimum_version 1.5.0
load '/usr/lib/bats/bats-support/load.bash'
load '/usr/lib/bats/bats-assert/load.bash'
load '/usr/lib/bats/bats-file/load.bash'

# Setup/teardown helpers
setup() {
    source "$BATS_TEST_DIRNAME/lib.bash"

    TEST_TEMP_DIR="$(temp_make)"
    TEST_FILE="$TEST_TEMP_DIR/TEST_PROMPT.md"
}

teardown() {
    temp_del "$TEST_TEMP_DIR"
}

count_trailing_newlines() {
    local file="$1"
    tail -c 20 "$file" | od -An -c | grep -o '\\n' | wc -l
}

@test "insert_or_replace_block inserts block into empty file" {
    echo "# Test Header" > "$TEST_FILE"

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success

    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="sandbox-bwrap">'
    assert_file_contains "$TEST_FILE" '</patched-prompt-hint>'
}

@test "insert_or_replace_block is idempotent - no newline accumulation" {
    echo "# Test Header" > "$TEST_FILE"

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success
    size_after_first=$(wc -c < "$TEST_FILE")

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success
    size_after_second=$(wc -c < "$TEST_FILE")

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success
    size_after_third=$(wc -c < "$TEST_FILE")

    assert_equal "$size_after_first" "$size_after_second"
    assert_equal "$size_after_second" "$size_after_third"
}

@test "insert_or_replace_block replaces existing block" {
    echo "# Test Header" > "$TEST_FILE"

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success

    run bash -c "grep -c '<patched-prompt-hint block=\"sandbox-bwrap\">' '$TEST_FILE'"
    assert_output "1"

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success

    run bash -c "grep -c '<patched-prompt-hint block=\"sandbox-bwrap\">' '$TEST_FILE'"
    assert_output "1"
}

@test "remove_prompt_block removes block completely" {
    echo "# Test Header" > "$TEST_FILE"

    run insert_or_replace_block "$TEST_FILE" "sandbox-bwrap"
    assert_success

    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="sandbox-bwrap">'

    run remove_prompt_block "$TEST_FILE" "sandbox-bwrap"
    assert_success

    assert_file_not_contains "$TEST_FILE" '<patched-prompt-hint block="sandbox-bwrap">'
    assert_file_not_contains "$TEST_FILE" '</patched-prompt-hint>'
}

@test "replace_all_prompt_blocks handles multiple blocks" {
    echo "# Test Header" > "$TEST_FILE"

    run replace_all_prompt_blocks "$TEST_FILE" "" "sandbox-bwrap" "git-readonly"
    assert_success

    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="sandbox-bwrap">'
    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="git-readonly">'
}

@test "replace_all_prompt_blocks removes obsolete blocks" {
    echo "# Test Header" > "$TEST_FILE"

    run replace_all_prompt_blocks "$TEST_FILE" "" "sandbox-bwrap" "git-readonly" "sandbox-vm"
    assert_success

    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="sandbox-bwrap">'
    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="git-readonly">'
    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="sandbox-vm">'

    run replace_all_prompt_blocks "$TEST_FILE" "" "sandbox-bwrap" "git-readonly"
    assert_success

    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="sandbox-bwrap">'
    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="git-readonly">'
    assert_file_not_contains "$TEST_FILE" '<patched-prompt-hint block="sandbox-vm">'
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
    local allowlist="$TEST_TEMP_DIR/allowlist.txt"
    cat > "$allowlist" <<EOF
# Comment line
^example\.com$
^.*\.github\.com$

^api\.service\.net$
EOF

    run get_prompt_block "proxy-restrictions" "$allowlist"
    assert_success

    assert_output --partial "example.com"
    assert_output --partial "*github.com"
    assert_output --partial "api.service.net"
    refute_output --partial "# Comment"
}

@test "get_prompt_block fails for non-existent block" {
    run get_prompt_block "non-existent-block"
    assert_failure
    assert_output --partial "Block not found"
}

@test "remove_prompt_block safely handles non-existent block" {
    echo "# Test Header" > "$TEST_FILE"

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

    run stat -c "%a" "$TEST_FILE"
    assert_output "600"
}

@test "get_prompt_block output includes start and end markers" {
    run get_prompt_block "sandbox-bwrap"
    assert_success

    assert_line --index 0 '<patched-prompt-hint block="sandbox-bwrap">'

    last_line=$(get_prompt_block 'sandbox-bwrap' | tail -1)
    assert_equal "$last_line" '</patched-prompt-hint>'
}

@test "format_allowlist_for_prompt handles missing allowlist gracefully" {
    run format_allowlist_for_prompt "/nonexistent/allowlist.txt"
    assert_success
    assert_output ""
}

@test "multiple insert operations do not duplicate block content" {
    echo "# Original Content" > "$TEST_FILE"

    for i in {1..3}; do
        run insert_or_replace_block "$TEST_FILE" "git-readonly"
        assert_success
    done

    run bash -c "grep -c '<patched-prompt-hint block=\"git-readonly\">' '$TEST_FILE'"
    assert_output "1"

    run bash -c "grep -c '</patched-prompt-hint>' '$TEST_FILE'"
    assert_output "1"
}

@test "replace_all_prompt_blocks automatically includes default blocks" {
    echo "# Test Header" > "$TEST_FILE"

    run replace_all_prompt_blocks "$TEST_FILE" "" "sandbox-bwrap"
    assert_success

    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="communication">'
    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="conventions">'
    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="sandbox-bwrap">'
}

@test "replace_all_prompt_blocks includes only default blocks when no others specified" {
    echo "# Test Header" > "$TEST_FILE"

    run replace_all_prompt_blocks "$TEST_FILE" ""
    assert_success

    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="communication">'
    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="conventions">'
    assert_file_not_contains "$TEST_FILE" '<patched-prompt-hint block="sandbox-bwrap">'
    assert_file_not_contains "$TEST_FILE" '<patched-prompt-hint block="git-readonly">'
}

@test "replace_all_prompt_blocks preserves user xml-like sections" {
    cat > "$TEST_FILE" <<EOF
# Test Header
<context>
user-owned section
</context>
EOF

    run replace_all_prompt_blocks "$TEST_FILE" "" "sandbox-bwrap"
    assert_success

    assert_file_contains "$TEST_FILE" "<context>"
    assert_file_contains "$TEST_FILE" "user-owned section"
    assert_file_contains "$TEST_FILE" "</context>"
}

@test "replace_all_prompt_blocks removes legacy blocks during upgrade" {
    cat > "$TEST_FILE" <<EOF
# Test Header
<!-- SANDBOX-BLOCK: communication -->
old communication
<!-- END-SANDBOX-BLOCK: communication -->
<!-- SANDBOX-BLOCK: sandbox-vm -->
old sandbox
<!-- END-SANDBOX-BLOCK: sandbox-vm -->
EOF

    run replace_all_prompt_blocks "$TEST_FILE" "" "sandbox-bwrap"
    assert_success

    assert_file_not_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: communication -->"
    assert_file_not_contains "$TEST_FILE" "<!-- SANDBOX-BLOCK: sandbox-vm -->"
    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="communication">'
    assert_file_contains "$TEST_FILE" '<patched-prompt-hint block="sandbox-bwrap">'
}
