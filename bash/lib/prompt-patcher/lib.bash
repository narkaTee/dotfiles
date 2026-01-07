#!/usr/bin/env bash
# shellcheck shell=bash
# vim: ft=bash

PROMPTS_PATCHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCKS_DIR="$PROMPTS_PATCHER_DIR/blocks"

get_prompt_filename() {
    local tool_name="$1"
    case "$tool_name" in
        claude)   echo "CLAUDE.md" ;;
        gemini)   echo "GEMINI.md" ;;
        opencode) echo "AGENT.md" ;;
        *)
            echo "Unknown tool: $tool_name" >&2
            return 1
            ;;
    esac
}

format_allowlist_for_prompt() {
    local allowlist="$1"

    if [[ ! -f "$allowlist" ]]; then
        return 0  # Silent fail
    fi

    # Skip comments and empty lines, convert regex to readable format
    grep -v '^#' "$allowlist" 2>/dev/null | grep -v '^[[:space:]]*$' | \
    sed 's/\^//g; s/\$//g; s/\\\././g; s/\.\*\./*/g' | \
    sort
}

get_prompt_block() {
    local block_id="$1"
    local allowlist_path="${2:-}"
    local block_file="$BLOCKS_DIR/${block_id}.md"

    if [[ ! -f "$block_file" ]]; then
        echo "Block not found: $block_id" >&2
        return 1
    fi

    # Output with markers
    echo "<!-- SANDBOX-BLOCK: $block_id -->"

    # If this is proxy-restrictions and allowlist exists, inject it
    if [[ "$block_id" == "proxy-restrictions" ]]; then
        sed '/<!-- ALLOWLIST_START -->/q' "$block_file"
        format_allowlist_for_prompt "$allowlist_path"
        sed -n '/<!-- ALLOWLIST_END -->/,$p' "$block_file"
    else
        cat "$block_file"
    fi

    echo "<!-- END-SANDBOX-BLOCK: $block_id -->"
}

remove_prompt_block() {
    local file="$1"
    local block_id="$2"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local start_marker="<!-- SANDBOX-BLOCK: $block_id -->"
    local end_marker="<!-- END-SANDBOX-BLOCK: $block_id -->"

    # Check if block exists
    if ! grep -qF "$start_marker" "$file"; then
        return 0
    fi

    # Use sed to remove from start to end marker (inclusive)
    # Create temp file to avoid in-place editing issues
    local temp_file
    temp_file="$(mktemp)"
    sed "/$(printf '%s' "$start_marker" | sed 's/[]\/$*.^[]/\\&/g')/,/$(printf '%s' "$end_marker" | sed 's/[]\/$*.^[]/\\&/g')/d" "$file" > "$temp_file"
    mv "$temp_file" "$file"
}

insert_or_replace_block() {
    local file="$1"
    local block_id="$2"
    local allowlist_path="${3:-}"

    remove_prompt_block "$file" "$block_id"

    get_prompt_block "$block_id" "$allowlist_path" >> "$file"
    echo "" >> "$file"  # Add blank line between blocks
}

get_existing_block_ids() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    # Extract block IDs from start markers
    grep -oP '<!-- SANDBOX-BLOCK: \K[^ ]+(?= -->)' "$file" || true
}

remove_obsolete_blocks() {
    local file="$1"
    shift
    local desired_blocks=("$@")

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    # Get existing blocks
    local existing_blocks
    mapfile -t existing_blocks < <(get_existing_block_ids "$file")

    # Remove blocks not in desired list
    local block_id
    for block_id in "${existing_blocks[@]}"; do
        local keep=false
        local desired
        for desired in "${desired_blocks[@]}"; do
            if [[ "$block_id" == "$desired" ]]; then
                keep=true
                break
            fi
        done

        if ! $keep; then
            remove_prompt_block "$file" "$block_id"
        fi
    done
}

replace_all_prompt_blocks() {
    local file="$1"
    local allowlist_path="$2"
    shift 2
    local blocks=("$@")

    remove_obsolete_blocks "$file" "${blocks[@]}"

    local block_id
    for block_id in "${blocks[@]}"; do
        insert_or_replace_block "$file" "$block_id" "$allowlist_path"
    done
}
