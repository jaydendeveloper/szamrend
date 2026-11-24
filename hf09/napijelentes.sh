#!/usr/bin/env bash
set -euo pipefail

format=szoveg
refresh=0
while (( $# )); do
    case $1 in
        --formatum)
            (( $# >= 2 )) || { printf 'Hiba: hiányzik a formátum.\n' >&2; exit 2; }
            format=$2
            shift 2
            ;;
        --frissits) refresh=1; shift ;;
        -h|--help)
            printf 'Használat: %s [--formatum szoveg|json] [--frissits]\n' "${0##*/}"
            exit 0
            ;;
        *) printf 'Hiba: ismeretlen kapcsoló: %s\n' "$1" >&2; exit 2 ;;
    esac
done
[[ $format == szoveg || $format == json ]] || { printf 'Hiba: a formátum szoveg vagy json lehet.\n' >&2; exit 2; }
for cmd in curl jq; do
    command -v "$cmd" >/dev/null || { printf 'Hiba: hiányzik a(z) %s.\n' "$cmd" >&2; exit 1; }
done

export TZ=Europe/Budapest
today=$(date +%Y-%m-%d)
year=$(date +%Y)
next_year=$((10#$year + 1))
cache=${XDG_CACHE_HOME:-$HOME/.cache}/napijelentes
mkdir -p "$cache"
tmp=$(mktemp -d "$cache/.tmp.XXXXXXXX")
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
failures=0

fetch() {
    local key=$1 url=$2 cached=$cache/${3:-$1}.json
    if (( ! refresh )) && [[ -f $cached ]] &&
        [[ -n $(find "$cached" -mmin -60 -print) ]] && jq -e . "$cached" >/dev/null 2>&1; then
        cp "$cached" "$tmp/$key.json"
        return
    fi
    if ! curl --fail --silent --show-error --location --connect-timeout 5 --max-time 12 \
        --output "$tmp/$key.download" "$url"; then
        printf 'Hiba: %s adatai nem tölthetők le.\n' "$key" >&2
    elif ! jq -e . "$tmp/$key.download" >/dev/null 2>&1; then
        printf 'Hiba: %s válasza nem érvényes JSON.\n' "$key" >&2
    else
        cp "$tmp/$key.download" "$tmp/$key.json"
        mv "$tmp/$key.download" "$cached"
        return
    fi
    failures=$((failures + 1))
    printf 'null\n' > "$tmp/$key.json"
}

fetch arfolyam "${ARFOLYAM_URL:-https://api.frankfurter.dev/v1/latest?base=EUR&symbols=HUF,USD}"
fetch idojaras "${IDOJARAS_URL:-https://api.open-meteo.com/v1/forecast?latitude=47.5&longitude=19.05&daily=temperature_2m_max,temperature_2m_min&timezone=Europe%2FBudapest}"
fetch unnep "${UNNEP_URL:-https://date.nager.at/api/v3/PublicHolidays/$year/HU}" "unnep-$year"
fetch unnep_kovetkezo "${UNNEP_KOVETKEZO_URL:-https://date.nager.at/api/v3/PublicHolidays/$next_year/HU}" "unnep-$next_year"

report=$(jq -n --arg today "$today" \
    --slurpfile rates "$tmp/arfolyam.json" --slurpfile weather "$tmp/idojaras.json" \
    --slurpfile holidays "$tmp/unnep.json" --slurpfile next_holidays "$tmp/unnep_kovetkezo.json" '
    def obj: if type == "object" then . else {} end;
    def arr: if type == "array" then . else [] end;
    def number_or_null: if type == "number" then . else null end;
    def string_or_null: if type == "string" then . else null end;
    def day_weather($daily; $date):
      (($daily.time | arr) | index($date)) as $i |
      {datum: $date,
       minimum: (if $i == null then null else (($daily.temperature_2m_min | arr)[$i] | number_or_null) end),
       maximum: (if $i == null then null else (($daily.temperature_2m_max | arr)[$i] | number_or_null) end)};
    ($today + "T00:00:00Z" | fromdateiso8601) as $epoch |
    (($epoch + 86400) | strftime("%Y-%m-%d")) as $tomorrow |
    ($rates[0] | obj) as $r | ($r.rates | obj) as $rr |
    ($weather[0] | obj | .daily | obj) as $d |
    ([($holidays[0] | arr)[], ($next_holidays[0] | arr)[] |
        select(type == "object" and (.date | type == "string")) |
        select(.date >= $today) |
        . as $h | (try (($h.date + "T00:00:00Z") | fromdateiso8601) catch null) as $h_epoch |
        select($h_epoch != null) |
        {datum: $h.date, nev: ($h.localName | string_or_null), napok_mulva: (($h_epoch - $epoch) / 86400)}] |
        sort_by(.datum) | .[0] // null) as $holiday |
    {keszult: $today, arfolyam: {datum: ($r.date | string_or_null), EUR_HUF: ($rr.HUF | number_or_null), EUR_USD: ($rr.USD | number_or_null)},
     idojaras: {ma: day_weather($d; $today), holnap: day_weather($d; $tomorrow)}, kovetkezo_unnep: $holiday}
')

if [[ $format == json ]]; then
    printf '%s\n' "$report"
else
    printf '%s\n' "$report" | jq -r '
      def show: if . == null then "nem elérhető" else tostring end;
      "Napi jelentés: \(.keszult)\n" +
      "Árfolyam dátuma: \(.arfolyam.datum | show)\n" +
      "1 EUR = \(.arfolyam.EUR_HUF | show) HUF; \(.arfolyam.EUR_USD | show) USD\n" +
      "Budapest ma (\(.idojaras.ma.datum)): min. \(.idojaras.ma.minimum | show), max. \(.idojaras.ma.maximum | show) °C\n" +
      "Budapest holnap (\(.idojaras.holnap.datum)): min. \(.idojaras.holnap.minimum | show), max. \(.idojaras.holnap.maximum | show) °C\n" +
      (if .kovetkezo_unnep == null then "Következő ünnepnap: nem elérhető"
       else "Következő ünnepnap: \(.kovetkezo_unnep.nev | show) (\(.kovetkezo_unnep.datum)), \(.kovetkezo_unnep.napok_mulva) nap múlva" end)'
fi
(( failures == 0 ))
