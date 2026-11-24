#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || ! -f $1 || ! -r $1 ]]; then
    printf 'Használat: %s URL-lista célkönyvtár\n' "${0##*/}" >&2
    exit 2
fi

list=$1
dest=$2
mkdir -p "$dest"
dest=$(cd "$dest" && pwd -P)
log=$dest/letoltes.log
tmp=$(mktemp -d "$dest/.letoltes.XXXXXXXX")
cleanup() {
    rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

log_event() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$*" >> "$log"
}

success=0
failure=0
index=0
declare -a failed_urls=()
declare -a failed_reasons=()
declare -a succeeded_urls=()
log_event 'Letöltés indult.'
while IFS= read -r url || [[ -n $url ]]; do
    [[ -n $url && $url != \#* ]] || continue
    index=$((index + 1))
    name=${url%%\?*}
    name=${name%%\#*}
    name=${name##*/}
    [[ -n $name && $name != . && $name != .. ]] || name=index
    name=$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '_')
    target=$(printf '%s/%04d-%s' "$dest" "$index" "$name")
    reason=''
    if [[ -e $target || -L $target ]]; then
        reason='A célfájl már létezik.'
    else
        for attempt in 1 2 3; do
            log_event "$index. URL: $url; $attempt. próbálkozás"
            if curl --fail --location --silent --show-error --connect-timeout 10 --max-time 30 \
                --output "$tmp/download" "$url" 2> "$tmp/curl-error"; then
                if [[ -s $tmp/download ]]; then
                    if mv "$tmp/download" "$target"; then
                        log_event "Siker: $url -> $target"
                        success=$((success + 1))
                        succeeded_urls[${#succeeded_urls[@]}]=$url
                    else
                        reason='Nem sikerült a célfájl létrehozása.'
                    fi
                    break
                fi
                reason='Üres válasz.'
            else
                rc=$?
                reason="curl hibakód: $rc; $(< "$tmp/curl-error")"
            fi
            log_event "Sikertelen próbálkozás: $reason"
            if (( attempt < 3 )); then
                wait_seconds=$((1 << (attempt - 1)))
                log_event "Várakozás: ${wait_seconds}s"
                sleep "$wait_seconds"
            fi
        done
    fi
    if [[ -n $reason && ! -f $target ]]; then
        failure=$((failure + 1))
        failed_urls[${#failed_urls[@]}]=$url
        failed_reasons[${#failed_reasons[@]}]=$reason
        log_event "Végleges hiba: $url; $reason"
    elif [[ $reason == 'A célfájl már létezik.' ]]; then
        failure=$((failure + 1))
        failed_urls[${#failed_urls[@]}]=$url
        failed_reasons[${#failed_reasons[@]}]=$reason
        log_event "Végleges hiba: $url; $reason"
    fi
done < "$list"

log_event "Befejezve: siker=$success, hiba=$failure."
printf 'Sikeres: %d; sikertelen: %d\n' "$success" "$failure"
for ((i=0; i<success; i++)); do
    printf '  Sikeres: %s\n' "${succeeded_urls[i]}"
done
for ((i=0; i<failure; i++)); do
    printf '  Sikertelen: %s: %s\n' "${failed_urls[i]}" "${failed_reasons[i]}"
done
(( failure == 0 ))
