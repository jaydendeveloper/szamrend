#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export LC_ALL=C

keep=${3-7}
if [[ $# -lt 2 || $# -gt 3 || ! -d ${1-} || ! $keep =~ ^[1-9][0-9]*$ || ${#keep} -gt 9 ]]; then
    printf 'Használat: %s forráskönyvtár célkönyvtár [megtartandó_darab=7]\n' "${0##*/}" >&2
    exit 2
fi
source_dir=$(cd "$1" && pwd -P)
mkdir -p "$2"
dest=$(cd "$2" && pwd -P)
if [[ $source_dir == / ]]; then
    printf 'Hiba: a gyökérkönyvtár nem menthető ezen a módon.\n' >&2
    exit 1
fi
case "$dest/" in
    "$source_dir/"*) printf 'Hiba: a cél nem lehet a forráson belül.\n' >&2; exit 1 ;;
esac
log=$dest/mentes.log
lock=$dest/.mentes.lock
recovery=$dest/.mentes.recovery
log_event() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$*" >> "$log"
}
log_event 'Mentés indítása.'
if ! mkdir "$lock" 2>/dev/null; then
    if ! mkdir "$recovery" 2>/dev/null; then
        printf 'Egy másik mentés vagy zárolás-helyreállítás fut.\n' >&2
        exit 1
    fi
    old_pid=''
    [[ ! -f $lock/pid ]] || IFS= read -r old_pid < "$lock/pid" || true
    if [[ $old_pid =~ ^[1-9][0-9]*$ ]] && ! kill -0 "$old_pid" 2>/dev/null && ! ps -p "$old_pid" >/dev/null 2>&1; then
        rm -f "$lock/pid"
        rmdir "$lock"
        log_event "Elavult zárolás eltávolítva: PID $old_pid."
    else
        rmdir "$recovery"
        log_event 'Másik mentés fut, vagy a zárolás nem ellenőrizhető.'
        printf 'Másik mentés fut, vagy a zárolás nem ellenőrizhető.\n' >&2
        exit 1
    fi
    rmdir "$recovery"
    if ! mkdir "$lock" 2>/dev/null; then
        printf 'Másik mentés fut.\n' >&2
        exit 1
    fi
fi
printf '%s\n' "$$" > "$lock/pid"
tmp=''
cleanup() {
    local result=$?
    if (( result != 0 )); then
        log_event "A mentés hibával leállt (exit: $result)." || printf 'Hiba: a napló nem írható.\n' >&2
    fi
    if [[ -n $tmp && -d $tmp ]]; then rm -rf "$tmp"; fi
    rm -f "$lock/pid"
    rmdir "$lock"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ -d $recovery ]]; then
    printf 'Zárolás-helyreállítás folyamatban van.\n' >&2
    exit 1
fi
tmp=$(mktemp -d "$dest/.mentes.tmp.XXXXXXXX")
name=mentes-$(date '+%Y-%m-%d-%H%M').tar.gz
if [[ -e $dest/$name || -L $dest/$name || -e $dest/$name.sha256 || -L $dest/$name.sha256 || -e $dest/$name.meta || -L $dest/$name.meta ]]; then
    log_event "Hiba: a mentés már létezik: $name."
    printf 'Hiba: ebben a percben már készült mentés: %s\n' "$name" >&2
    exit 1
fi
log_event "Archívum készítése: $source_dir -> $name."
tar -czf "$tmp/$name" -C "$source_dir" .
(cd "$tmp" && shasum -a 256 "$name" > "$name.sha256")
size=$(wc -c < "$tmp/$name" | tr -d ' ')
count=$(find "$source_dir" -type f -print0 | { n=0; while IFS= read -r -d ''; do n=$((n + 1)); done; printf '%s\n' "$n"; })
printf 'Készült: %s\nMéret: %s bájt\nFájlok: %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$size" "$count" > "$tmp/$name.meta"
mv "$tmp/$name.sha256" "$dest/"
mv "$tmp/$name.meta" "$dest/"
mv "$tmp/$name" "$dest/"
log_event "Mentés kész: $name, $size bájt, $count fájl."

archives=()
for path in "$dest"/mentes-????-??-??-????.tar.gz; do
    [[ -f $path ]] || continue
    base=${path##*/}
    [[ $base =~ ^mentes-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}\.tar\.gz$ ]] || continue
    archives[${#archives[@]}]=$path
done
remove_count=$((${#archives[@]} - keep))
for ((i=0; i<remove_count; i++)); do
    old=${archives[i]}
    rm -f "$old" "$old.sha256" "$old.meta"
    log_event "Retenció törölte: ${old##*/}."
done
printf 'Mentés kész: %s\n' "$dest/$name"
