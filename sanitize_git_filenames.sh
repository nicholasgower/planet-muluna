sanitize_git_filenames() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
        echo "Not inside a Git repository."
        return 1
    }

    # Characters forbidden on Windows
    local forbidden='[<>:"/\\|?*]'
    local replacement="_"

    # Crawl through repo
    find "$repo_root" -depth -name '*[<>:"/\\|?*]*' | while IFS= read -r file; do
        dir=$(dirname "$file")
        base=$(basename "$file")

        # Generate new safe filename
        safe=$(echo "$base" | sed "s/$forbidden/$replacement/g")

        # If it changed, rename
        if [[ "$base" != "$safe" ]]; then
            echo "Renaming: $file -> $dir/$safe"
            git mv -f "$file" "$dir/$safe"
        fi
    done
}

# How it works:

#     Uses git rev-parse --show-toplevel to find the repo root.

#     find … -depth ensures we rename files before directories (avoids breaking paths).

#     sed "s/$forbidden/$replacement/g" replaces all forbidden characters with _.

#     Uses git mv -f to rename so Git tracks the move.

# Example usage:

# cd /path/to/repo
# sanitize_git_filenames

# This will scan the repo and automatically rename anything invalid on Windows.

# Do you want me to also handle reserved names like CON, NUL, COM1 etc. (which are valid in Linux but not in Windows), or just forbidden characters?

