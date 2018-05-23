bigdir() {
    dir="$1"
    if [ -z "$dir" ]; then
        dir="."
    fi
    find "$dir" -mindepth 1 -maxdepth 1 -type d -exec du -sh {} \; | sort -h | more
}
