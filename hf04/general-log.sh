#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || -z $1 ]]; then
    printf 'Használat: %s NEPTUN\n' "${0##*/}" >&2
    exit 1
fi

export LC_ALL=C
seed=$(printf '%s' "$1" | cksum | awk '{print $1}')
awk -v seed="$seed" '
function timestamp(t,    days, sec, year, month, day, leap, lengths, names) {
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", names, " ")
    split("31 28 31 30 31 30 31 31 30 31 30 31", lengths, " ")
    days = int(t / 86400)
    sec = t % 86400
    year = 1970
    while (1) {
        leap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))
        if (days < 365 + leap) break
        days -= 365 + leap
        year++
    }
    lengths[2] += leap
    month = 1
    while (days >= lengths[month]) {
        days -= lengths[month]
        month++
    }
    day = days + 1
    return sprintf("%02d/%s/%04d:%02d:%02d:%02d +0200", day, names[month], year,
                   int(sec / 3600), int(sec % 3600 / 60), sec % 60)
}
BEGIN {
    srand(seed)
    nu = split("/ /index.html /api/v1/users /api/v1/orders /login /admin /static/app.js /kepek/logo.png", ut, " ")
    nm = split("GET GET GET GET POST POST PUT DELETE", md, " ")
    ns = split("200 200 200 200 200 301 404 403 500 502", st, " ")
    for (i = 0; i < 4000; i++) {
        ip = sprintf("%d.%d.%d.%d", 10+int(rand()*40), int(rand()*256), int(rand()*256), 1+int(rand()*254))
        if (rand() < 0.18) ip = "193.224.41.77"
        t = 1790000000 + i*17 + int(rand()*11)
        printf "%s - - [%s] \"%s %s HTTP/1.1\" %s %d %.3f\n", ip,
            timestamp(t), md[int(rand()*nm)+1], ut[int(rand()*nu)+1],
            st[int(rand()*ns)+1], 200+int(rand()*90000), rand()*2.5
    }
}'
