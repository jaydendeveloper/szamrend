# Webszerver-log riport

Generálás és futtatás Bash-sel:

```sh
bash hf04/general-log.sh qqzt9p > access.log
bash hf04/logriport.sh access.log
```

Más Neptun-kóddal más adatsor generálható. A generátor az eredeti feladat véletlen adatait és időbélyeg-formátumát követi; az időbélyeget a macOS alapértelmezett awk-jával is működő kód állítja elő. A véletlenszám-generátor megvalósítása rendszerenként eltérhet. A riport az időbélyegben szereplő órákat használja, időzóna-átváltás nélkül.

Teszteléshez a `qqzt9p` kóddal generált 4000 soros logot és külön létrehozott kis tesztlogokat használtam.

## Példakimenet

```text
KERESEK OSSZESITVE
  Osszes keres: 4000
  Egyedi IP:    3270

10 LEGAKTIVABB IP
  IP                      Keresek
  193.224.41.77               731
  10.1.35.78                    1
  10.10.173.127                 1
  10.100.61.35                  1
  10.101.33.220                 1
  10.102.63.64                  1
  10.104.109.99                 1
  10.108.65.120                 1
  10.109.122.130                1
  10.110.70.14                  1

STATUSZKODOK
  Kod           Keresek      Arany
  200              1973     49.33%
  301               396      9.90%
  403               383      9.57%
  404               414     10.35%
  500               414     10.35%
  502               420     10.50%

HIBAS KERESEK URL SZERINT (4xx, 5xx)
  URL                                         Keresek
  /                                               221
  /admin                                          169
  /api/v1/orders                                  199
  /api/v1/users                                   212
  /index.html                                     200
  /kepek/logo.png                                 215
  /login                                          203
  /static/app.js                                  212

ORANKENTI KERESEK
  Ora                     Keresek
  21/Sep/2026 14:00           165
  21/Sep/2026 15:00           211
  21/Sep/2026 16:00           212
  21/Sep/2026 17:00           212
  21/Sep/2026 18:00           212
  21/Sep/2026 19:00           212
  21/Sep/2026 20:00           212
  21/Sep/2026 21:00           211
  21/Sep/2026 22:00           212
  21/Sep/2026 23:00           212
  22/Sep/2026 00:00           212
  22/Sep/2026 01:00           212
  22/Sep/2026 02:00           211
  22/Sep/2026 03:00           212
  22/Sep/2026 04:00           211
  22/Sep/2026 05:00           213  <- csucs
  22/Sep/2026 06:00           211
  22/Sep/2026 07:00           212
  22/Sep/2026 08:00           212
  22/Sep/2026 09:00            23

ATLAGOS VALASZIDO (masodperc)
  Osszesen:      1.258
  200:           1.268
  500:           1.265

A legaktivabb IP a 193.224.41.77, ami az osszes keres 18.27%-at adta.
```
