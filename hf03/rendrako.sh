#!/usr/bin/env bash

set -eo pipefail

usage() {
    printf 'Használat: %s [--rendezd] könyvtár\n' "${0##*/}" >&2
}

dir=
organize=0
for arg in "$@"; do
    case $arg in
        --rendezd) organize=1 ;;
        --*) printf 'Ismeretlen kapcsoló: %s\n' "$arg" >&2; usage; exit 1 ;;
        *)
            if [[ -n $dir ]]; then
                usage
                exit 1
            fi
            dir=$arg
            ;;
    esac
done

if [[ -z $dir || ! -d $dir ]]; then
    printf 'Hiba: létező könyvtárat kell megadni.\n' >&2
    usage
    exit 1
fi


[[ $dir = /* ]] || dir=./$dir
while [[ $dir != / && $dir = */ ]]; do
    dir=${dir%/}
done
dest=${dir%/}/_rendezett

if stat -f '%z' "$dir" >/dev/null 2>&1; then
    stat_style=bsd
elif stat -c '%s' "$dir" >/dev/null 2>&1; then
    stat_style=gnu
else
    printf 'Hiba: a fájlméretek lekérdezése nem támogatott ezen a rendszeren.\n' >&2
    exit 1
fi

file_info() {
    if [[ $stat_style == bsd ]]; then
        size=$(stat -f '%z' "$1")
        mode=$(stat -f '%Lp' "$1")
    else
        size=$(stat -c '%s' "$1")
        mode=$(stat -c '%a' "$1")
    fi
}

get_extension() {
    local name=${1##*/}
    extension=
    if [[ $name == *.* && $name != *. ]]; then
        extension=${name##*.}
        # A .profil önmagában nem kiterjesztés.
        [[ $name != ".$extension" ]] || extension=
    fi
}

count_records() {
    local count=0 item
    while IFS= read -r -d '' item; do
        count=$((count + 1))
    done
    printf '%s\n' "$count"
}

directory_count=$(find -H "$dir" -mindepth 1 -type d -print0 | count_records)
old_count=$(find -H "$dir" -type f -mtime +30 -print0 | count_records)

find -H "$dir" -type f -print0 | {
    count=0
    extensions=()
    extension_counts=()
    largest_paths=()
    largest_sizes=()
    empty_files=()
    writable_files=()

    while IFS= read -r -d '' file; do
        file_info "$file"
        count=$((count + 1))
        [[ $size != 0 ]] || empty_files[${#empty_files[@]}]=$file
        case ${mode: -1} in
            2|3|6|7) writable_files[${#writable_files[@]}]=$file ;;
        esac

        get_extension "$file"
        i=0
        while (( i < ${#extensions[@]} )); do
            [[ ${extensions[i]} != "$extension" ]] || break
            i=$((i + 1))
        done
        if (( i == ${#extensions[@]} )); then
            extensions[i]=$extension
            extension_counts[i]=1
        else
            extension_counts[i]=$((extension_counts[i] + 1))
        fi

        i=0
        while (( i < ${#largest_sizes[@]} && i < 5 )); do
            (( size <= largest_sizes[i] )) || break
            i=$((i + 1))
        done
        if (( i < 5 )); then
            j=4
            while (( j > i )); do
                if (( j - 1 < ${#largest_sizes[@]} )); then
                    largest_sizes[j]=${largest_sizes[j-1]}
                    largest_paths[j]=${largest_paths[j-1]}
                fi
                j=$((j - 1))
            done
            largest_sizes[i]=$size
            largest_paths[i]=$file
        fi
    done

    printf 'Fájlok: %s\nKönyvtárak (a megadott nélkül): %s\n' "$count" "$directory_count"
    printf '\nAz 5 legnagyobb fájl (bájt):\n'
    for ((i=0; i<${#largest_paths[@]}; i++)); do
        printf '  %s  %q\n' "${largest_sizes[i]}" "${largest_paths[i]}"
    done
    printf '\n30 napnál régebben módosított fájlok: %s\n' "$old_count"
    printf '\nÜres fájlok:\n'
    for file in "${empty_files[@]}"; do printf '  %q\n' "$file"; done
    printf '\nKiterjesztések:\n'
    for ((i=0; i<${#extensions[@]}; i++)); do
        if [[ -n ${extensions[i]} ]]; then
            printf '  %q: %s\n' "${extensions[i]}" "${extension_counts[i]}"
        else
            printf '  (kiterjesztés nélkül): %s\n' "${extension_counts[i]}"
        fi
    done
    printf '\nMindenki számára írható fájlok:\n'
    for file in "${writable_files[@]}"; do printf '  %q\n' "$file"; done
}

if (( organize )); then
    if [[ -e $dest || -L $dest ]]; then
        printf '\nHiba: a cél már létezik, nem írom felül: %q\n' "$dest" >&2
        exit 1
    fi
    printf '\nRendezés: a fájlokat ide másolom kiterjesztés és eredeti útvonal szerint: %q\n' "$dest"
    printf 'Az eredeti és a másolt fájlokról is elveszem a mindenki számára írás jogát.\n'

    mkdir -- "$dest"
    dest_pattern=${dest//\\/\\\\}
    dest_pattern=${dest_pattern//\*/\\*}
    dest_pattern=${dest_pattern//\?/\\?}
    dest_pattern=${dest_pattern//\[/\\[}
    find -H "$dir" -path "$dest_pattern" -prune -o -type f -print0 | {
        while IFS= read -r -d '' file; do
            get_extension "$file"
            [[ -n $extension ]] || extension=_egyeb
            if [[ $dir == / ]]; then
                relative=${file#/}
            else
                relative=${file#"$dir"/}
            fi
            target=$dest/$extension/$relative
            mkdir -p -- "${target%/*}"
            cp -p -- "$file" "$target"
            file_info "$file"
            case ${mode: -1} in
                2|3|6|7)
                    chmod o-w "$target"
                    chmod o-w "$file"
                    printf 'Írási jog elvéve: %q\n' "$file"
                    ;;
            esac
        done
    }
fi
