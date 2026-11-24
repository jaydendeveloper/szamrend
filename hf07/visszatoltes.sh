#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export LC_ALL=C

if [[ $# -lt 1 ]]; then
    printf 'Használat: %s mentéskönyvtár [mentésnév|--legutobbi célkönyvtár [--proba]]\n' "${0##*/}" >&2
    exit 2
fi
[[ -d $1 ]] || { printf 'Hiba: nincs ilyen mentéskönyvtár.\n' >&2; exit 1; }
backup=$(cd "$1" && pwd -P)
archives=()
for path in "$backup"/mentes-????-??-??-????.tar.gz; do
    [[ -f $path ]] || continue
    name=${path##*/}
    [[ $name =~ ^mentes-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}\.tar\.gz$ ]] || continue
    archives[${#archives[@]}]=$name
done
if [[ $# == 1 ]]; then
    printf '%-32s %12s\n' 'Mentés (dátum a névben)' 'Bájt'
    for name in "${archives[@]}"; do
        size=$(wc -c < "$backup/$name" | tr -d ' ')
        printf '%-32s %12s\n' "$name" "$size"
    done
    exit 0
fi
if [[ $# -lt 3 || $# -gt 4 || ( $# == 4 && $4 != --proba ) ]]; then
    printf 'Hiba: hiányzó vagy hibás argumentum.\n' >&2
    exit 2
fi
name=$2
if [[ $name == --legutobbi ]]; then
    if (( ${#archives[@]} == 0 )); then printf 'Hiba: nincs mentés.\n' >&2; exit 1; fi
    name=${archives[${#archives[@]}-1]}
fi
if [[ ! $name =~ ^mentes-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}\.tar\.gz$ || ! -f $backup/$name || ! -f $backup/$name.sha256 ]]; then
    printf 'Hiba: nincs ilyen mentés vagy ellenőrzőösszeg.\n' >&2
    exit 1
fi
checksum=''
listed=''
IFS=' ' read -r checksum listed < "$backup/$name.sha256" || true
actual=$(shasum -a 256 "$backup/$name")
actual=${actual%% *}
if [[ ! $checksum =~ ^[0-9a-f]{64}$ || $listed != "$name" || $checksum != "$actual" ]]; then
    printf 'Hiba: az ellenőrzőösszeg nem egyezik; visszatöltés megtagadva.\n' >&2
    exit 1
fi
printf '%s: OK\n' "$name"
[[ -d $3 && ! -L $3 ]] || { printf 'Hiba: létező célkönyvtár szükséges.\n' >&2; exit 1; }
if [[ -n $(find "$3" -mindepth 1 -print -quit) ]]; then
    printf 'Hiba: a célkönyvtár nem üres; nem írok felül semmit.\n' >&2
    exit 1
fi
printf 'Visszatöltés: %s -> %s\n' "$name" "$3"
if [[ ${4-} == --proba ]]; then
    tar -tzf "$backup/$name"
else
    tar -xzf "$backup/$name" -C "$3"
    printf 'Visszatöltés kész.\n'
fi
