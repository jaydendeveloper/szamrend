#!/usr/bin/env bash
set -euo pipefail

readonly EX_OK=0 EX_USAGE=2 EX_NOFILE=3
readonly EX_ERROR=1

usage() {
    printf '%s\n' \
        'Használat: logtool.sh -f FÁJL [KAPCSOLÓK]' \
        '' \
        'Webszerver-log összesítése a HF4 formátumában.' \
        '  -h, --help          Súgó megjelenítése.' \
        '  -f, --file FÁJL     Feldolgozandó logfájl (kötelező).' \
        '  -t, --top N         Top IP-k száma, pozitív egész (alap: 10).' \
        '  -s, --status KÓD    Csak a megadott háromjegyű státuszkód.' \
        '  -o, --output FÁJL   Riport kiírása fájlba, a meglévő fájlt lecseréli.' \
        '  -q, --quiet         Csak a végső összefoglaló sor.' \
        '' \
        'A szűrés minden statisztikára érvényes; az órák a log időzónáját követik.' \
        'Kilépési kódok: 0 siker, 2 hibás használat, 3 nem olvasható bemenet, 1 egyéb hiba.'
}

hiba_hasznalat() {
    printf 'Hiba: %s\n\n' "$1" >&2
    usage >&2
    exit "$EX_USAGE"
}

parse_args() {
    while (( $# )); do
        case $1 in
            -h|--help) usage; exit "$EX_OK" ;;
            -q|--quiet) quiet=1; shift ;;
            -f|--file|-t|--top|-s|--status|-o|--output)
                (( $# >= 2 )) || hiba_hasznalat "Hiányzó érték: $1"
                [[ -n $2 && $2 != -* ]] || hiba_hasznalat "Hiányzó vagy hibás érték: $1"
                case $1 in
                    -f|--file) file=$2 ;;
                    -t|--top) top=$2 ;;
                    -s|--status) status=$2 ;;
                    -o|--output) output=$2 ;;
                esac
                shift 2
                ;;
            *) hiba_hasznalat "Ismeretlen kapcsoló vagy argumentum: $1" ;;
        esac
    done
    [[ -n $file ]] || hiba_hasznalat 'A -f/--file megadása kötelező.'
    [[ $top =~ ^[1-9][0-9]*$ && ${#top} -le 9 ]] || hiba_hasznalat 'A toplista mérete pozitív egész legyen (legfeljebb 9 számjegy).'
    [[ -z $status || $status =~ ^[1-5][0-9][0-9]$ ]] || hiba_hasznalat 'A státuszkód 100 és 599 közötti háromjegyű szám legyen.'
}

ellenoriz_bemenet() {
    if [[ ! -f $file || ! -r $file ]]; then
        printf 'Hiba: a logfájl nem létezik, nem fájl vagy nem olvasható: %s\n' "$file" >&2
        exit "$EX_NOFILE"
    fi
    [[ $file = /* ]] || file=./$file
    if [[ -n $output ]]; then
        [[ $output = /* ]] || output=./$output
        if [[ $file -ef $output || -d $output ]]; then
            printf 'Hiba: a kimenet nem lehet a bemeneti fájl vagy könyvtár: %s\n' "$output" >&2
            exit "$EX_ERROR"
        fi
    fi
}

top_ip() {
    printf '%s\n' '
function top_ip(    ip, i, j) {
    for (ip in ip_count) {
        unique++
        for (i = 1; i <= top && i <= unique; i++) {
            if (!(i in best) || ip_count[ip] > best_count[i] ||
                (ip_count[ip] == best_count[i] && ip < best[i])) {
                for (j = (unique < top ? unique : top); j > i; j--) {
                    if ((j-1) in best) {
                        best[j] = best[j-1]
                        best_count[j] = best_count[j-1]
                    }
                }
                best[i] = ip; best_count[i] = ip_count[ip]
                break
            }
        }
    }
}
function print_top(    i) {
    printf "%d LEGAKTIVABB IP\n  %-20s %10s\n", top, "IP", "Keresek"
    for (i = 1; i <= top && i in best; i++)
        printf "  %-20s %10d\n", best[i], best_count[i]
    if (!total) print "  Nincs adat."
}'
}

statusz_megoszlas() {
    printf '%s\n' '
function statusz_megoszlas(    n, code, i, keys) {
    print "\nSTATUSZKODOK"
    printf "  %-10s %10s %10s\n", "Kod", "Keresek", "Arany"
    for (code in status_count) keys[++n] = code
    sort_keys(keys, n)
    for (i = 1; i <= n; i++) {
        code = keys[i]
        printf "  %-10s %10d %9.2f%%\n", code, status_count[code], 100 * status_count[code] / total
    }
    if (!n) print "  Nincs adat."
}'
}

osszefoglalo() {
    printf '%s\n' '
function osszefoglalo() {
    if (total)
        printf "A legaktivabb IP a %s, ami az osszes keres %.2f%%-at adta.\n", best[1], 100 * best_count[1] / total
    else print "Nincs keres, igy legaktivabb IP sem allapithato meg."
}'
}

awk_rendezes() {
    cat <<'AWK'
function sort_keys(keys, n,    i, j, value) {
    for (i = 2; i <= n; i++) {
        value = keys[i]; j = i - 1
        while (j >= 1 && keys[j] > value) { keys[j+1] = keys[j]; j-- }
        keys[j+1] = value
    }
}
AWK
}

awk_alap() {
    cat <<'AWK'
BEGIN {
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", months, " ")
    for (i = 1; i <= 12; i++) month_number[months[i]] = sprintf("%02d", i)
}
{
    date = substr($4, 2); month = substr(date, 4, 3)
    if (NF != 11 || $9 !~ /^[0-9][0-9][0-9]$/ ||
        $11 !~ /^[0-9]+([.][0-9]+)?$/ ||
        date !~ /^[0-9][0-9]\/[A-Za-z][A-Za-z][A-Za-z]\/[0-9][0-9][0-9][0-9]:[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/ ||
        !(month in month_number)) {
        printf "Hiba: hibas logformatum a(z) %d. sorban.\n", NR > "/dev/stderr"
        bad = 1; exit 1
    }
    if (filter != "" && $9 != filter) next
    total++; ip_count[$1]++; status_count[$9]++
    if ($9 >= 400 && $9 < 600) error_count[$7]++
    hour = substr(date, 8, 4) month_number[month] substr(date, 1, 2) substr(date, 13, 2)
    hour_count[hour]++; hour_label[hour] = substr(date, 1, 11) " " substr(date, 13, 2) ":00"
    response_sum += $11
    if ($9 == 200 || $9 == 500) { response_by_status[$9] += $11; response_count[$9]++ }
}
AWK
}

hibak_riportja() {
    printf '%s\n' '
function error_report(    n, url, i, keys) {
    print "\nHIBAS KERESEK URL SZERINT (4xx, 5xx)"
    printf "  %-40s %10s\n", "URL", "Keresek"
    for (url in error_count) keys[++n] = url
    sort_keys(keys, n)
    for (i = 1; i <= n; i++) printf "  %-40s %10d\n", keys[i], error_count[keys[i]]
    if (!n) print "  Nincs hibas keres."
}'
}

ora_riportja() {
    printf '%s\n' '
function hour_report(    n, hour, peak, i, keys) {
    print "\nORANKENTI KERESEK"
    printf "  %-20s %10s\n", "Ora", "Keresek"
    for (hour in hour_count) {
        keys[++n] = hour
        if (hour_count[hour] > peak) peak = hour_count[hour]
    }
    sort_keys(keys, n)
    for (i = 1; i <= n; i++) {
        hour = keys[i]
        printf "  %-20s %10d%s\n", hour_label[hour], hour_count[hour], (hour_count[hour] == peak ? "  <- csucs" : "")
    }
    if (!n) print "  Nincs adat."
}'
}

valaszido_riportja() {
    printf '%s\n' '
function response_report(    i, code) {
    print "\nATLAGOS VALASZIDO (masodperc)"
    if (total) printf "  Osszesen: %10.3f\n", response_sum / total
    else print "  Osszesen: nincs adat"
    for (i = 1; i <= 2; i++) {
        code = i == 1 ? 200 : 500
        if (response_count[code]) printf "  %-9s %10.3f\n", code ":", response_by_status[code] / response_count[code]
        else printf "  %-9s nincs adat\n", code ":"
    }
}'
}

riport() {
    local program
    program="$(awk_rendezes)
$(awk_alap)
$(top_ip)
$(statusz_megoszlas)
$(osszefoglalo)
$(hibak_riportja)
$(ora_riportja)
$(valaszido_riportja)
END {
    if (bad) exit 1
    top_ip()
    if (!quiet) {
        printf \"KERESEK OSSZESITVE\n  Osszes keres: %d\n  Egyedi IP:    %d\n\n\", total, unique
        print_top(); statusz_megoszlas(); error_report(); hour_report(); response_report()
        print \"\"
    }
    osszefoglalo()
}"
    awk -v top="$top" -v filter="$status" -v quiet="$quiet" "$program" "$file"
}

futtatas() {
    local temp
    if [[ -z $output ]]; then
        riport
    else
        temp=$(mktemp "${output}.tmp.XXXXXX") || {
            printf 'Hiba: nem hozható létre ideiglenes kimenet: %s\n' "$output" >&2
            return "$EX_ERROR"
        }
        if ! riport > "$temp"; then
            rm -f "$temp"
            return "$EX_ERROR"
        fi
        if ! mv -f "$temp" "$output"; then
            printf 'Hiba: nem írható a kimenet: %s\n' "$output" >&2
            rm -f "$temp"
            return "$EX_ERROR"
        fi
    fi
}

main() {
    local file='' top=10 status='' output='' quiet=0
    export LC_ALL=C
    parse_args "$@"
    ellenoriz_bemenet
    futtatas
}

main "$@"
