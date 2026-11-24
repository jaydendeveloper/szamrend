#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Használat: %s logfájl\n' "${0##*/}" >&2
    exit 1
fi

file=$1
if [[ ! -f $file || ! -r $file ]]; then
    printf 'Hiba: a logfájl nem létezik, nem fájl vagy nem olvasható: %s\n' "$file" >&2
    exit 1
fi
[[ $file = /* ]] || file=./$file
export LC_ALL=C

awk '
function sort_keys(keys, n,    i, j, value) {
    for (i = 2; i <= n; i++) {
        value = keys[i]
        j = i - 1
        while (j >= 1 && keys[j] > value) {
            keys[j+1] = keys[j]
            j--
        }
        keys[j+1] = value
    }
}
BEGIN {
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", months, " ")
    for (i = 1; i <= 12; i++) month_number[months[i]] = sprintf("%02d", i)
}
{
    date = substr($4, 2)
    month = substr(date, 4, 3)
    if (NF != 11 || $9 !~ /^[0-9][0-9][0-9]$/ ||
        $11 !~ /^[0-9]+([.][0-9]+)?$/ ||
        date !~ /^[0-9][0-9]\/[A-Za-z][A-Za-z][A-Za-z]\/[0-9][0-9][0-9][0-9]:[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/ ||
        !(month in month_number)) {
        printf "Hiba: hibás logformátum a(z) %d. sorban.\n", NR > "/dev/stderr"
        bad = 1
        exit 1
    }
    total++
    ip_count[$1]++
    status_count[$9]++
    if ($9 >= 400 && $9 < 600) error_count[$7]++
    hour = substr(date, 8, 4) month_number[month] substr(date, 1, 2) substr(date, 13, 2)
    hour_count[hour]++
    hour_label[hour] = substr(date, 1, 11) " " substr(date, 13, 2) ":00"
    response_sum += $11
    if ($9 == 200 || $9 == 500) {
        response_by_status[$9] += $11
        response_count[$9]++
    }
}
END {
    if (bad) exit 1
    unique = 0
    for (ip in ip_count) {
        unique++
        for (i = 1; i <= 10; i++) {
            if (!(i in top_ip) || ip_count[ip] > top_count[i] ||
                (ip_count[ip] == top_count[i] && ip < top_ip[i])) {
                for (j = 10; j > i; j--) {
                    if ((j-1) in top_ip) {
                        top_ip[j] = top_ip[j-1]
                        top_count[j] = top_count[j-1]
                    }
                }
                top_ip[i] = ip
                top_count[i] = ip_count[ip]
                break
            }
        }
    }
    printf "KERESEK OSSZESITVE\n"
    printf "  Osszes keres: %d\n  Egyedi IP:    %d\n\n", total, unique
    printf "10 LEGAKTIVABB IP\n  %-20s %10s\n", "IP", "Keresek"
    for (i = 1; i <= 10 && i in top_ip; i++)
        printf "  %-20s %10d\n", top_ip[i], top_count[i]
    if (!total) printf "  Nincs adat.\n"

    printf "\nSTATUSZKODOK\n  %-10s %10s %10s\n", "Kod", "Keresek", "Arany"
    n = 0
    for (status in status_count) statuses[++n] = status
    sort_keys(statuses, n)
    for (i = 1; i <= n; i++) {
        status = statuses[i]
        printf "  %-10s %10d %9.2f%%\n", status, status_count[status], 100 * status_count[status] / total
    }
    if (!n) printf "  Nincs adat.\n"

    printf "\nHIBAS KERESEK URL SZERINT (4xx, 5xx)\n  %-40s %10s\n", "URL", "Keresek"
    n = 0
    for (url in error_count) urls[++n] = url
    sort_keys(urls, n)
    for (i = 1; i <= n; i++)
        printf "  %-40s %10d\n", urls[i], error_count[urls[i]]
    if (!n) printf "  Nincs hibas keres.\n"

    printf "\nORANKENTI KERESEK\n  %-20s %10s\n", "Ora", "Keresek"
    n = 0
    peak = 0
    for (hour in hour_count) {
        hours[++n] = hour
        if (hour_count[hour] > peak) peak = hour_count[hour]
    }
    sort_keys(hours, n)
    for (i = 1; i <= n; i++) {
        hour = hours[i]
        printf "  %-20s %10d%s\n", hour_label[hour], hour_count[hour], (hour_count[hour] == peak ? "  <- csucs" : "")
    }
    if (!n) printf "  Nincs adat.\n"

    printf "\nATLAGOS VALASZIDO (masodperc)\n"
    if (total) printf "  Osszesen: %10.3f\n", response_sum / total
    else printf "  Osszesen: nincs adat\n"
    for (i = 1; i <= 2; i++) {
        status = i == 1 ? 200 : 500
        if (response_count[status])
            printf "  %-9s %10.3f\n", status ":", response_by_status[status] / response_count[status]
        else printf "  %-9s nincs adat\n", status ":"
    }
    if (total)
        printf "\nA legaktivabb IP a %s, ami az osszes keres %.2f%%-at adta.\n", top_ip[1], 100 * top_count[1] / total
    else printf "\nNincs keres, igy legaktivabb IP sem allapithato meg.\n"
}' "$file"
