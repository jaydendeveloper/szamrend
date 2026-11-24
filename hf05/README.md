# Logtool

A program a HF4 generátorának logformátumát dolgozza fel. Példa log készítése:

```sh
bash hf04/general-log.sh qqzt9p > access.log
```

## Súgó

```text
Használat: logtool.sh -f FÁJL [KAPCSOLÓK]

Webszerver-log összesítése a HF4 formátumában.
  -h, --help          Súgó megjelenítése.
  -f, --file FÁJL     Feldolgozandó logfájl (kötelező).
  -t, --top N         Top IP-k száma, pozitív egész (alap: 10).
  -s, --status KÓD    Csak a megadott háromjegyű státuszkód.
  -o, --output FÁJL   Riport kiírása fájlba, a meglévő fájlt lecseréli.
  -q, --quiet         Csak a végső összefoglaló sor.

A szűrés minden statisztikára érvényes; az órák a log időzónáját követik.
Kilépési kódok: 0 siker, 2 hibás használat, 3 nem olvasható bemenet, 1 egyéb hiba.
```

## Példák

A következő kimenetek a `qqzt9p` kóddal, macOS-en generált logból készültek.

```text
$ ./hf05/logtool.sh -f access.log -t 3 -s 404
KERESEK OSSZESITVE
  Osszes keres: 414
  Egyedi IP:    350

3 LEGAKTIVABB IP
  IP                      Keresek
  193.224.41.77                65
  10.1.35.78                    1
  10.117.36.233                 1

STATUSZKODOK
  Kod           Keresek      Arany
  404               414    100.00%

HIBAS KERESEK URL SZERINT (4xx, 5xx)
  URL                                         Keresek
  /                                                54
  /admin                                           41
  /api/v1/orders                                   48
  /api/v1/users                                    59
  /index.html                                      57
  /kepek/logo.png                                  40
  /login                                           52
  /static/app.js                                   63

ORANKENTI KERESEK
  Ora                     Keresek
  21/Sep/2026 14:00            14
  21/Sep/2026 15:00            22
  21/Sep/2026 16:00            19
  21/Sep/2026 17:00            21
  21/Sep/2026 18:00            26
  21/Sep/2026 19:00            28
  21/Sep/2026 20:00            15
  21/Sep/2026 21:00            20
  21/Sep/2026 22:00            25
  21/Sep/2026 23:00            21
  22/Sep/2026 00:00            22
  22/Sep/2026 01:00            22
  22/Sep/2026 02:00            14
  22/Sep/2026 03:00            26
  22/Sep/2026 04:00            22
  22/Sep/2026 05:00            26
  22/Sep/2026 06:00            29  <- csucs
  22/Sep/2026 07:00            25
  22/Sep/2026 08:00            16
  22/Sep/2026 09:00             1

ATLAGOS VALASZIDO (masodperc)
  Osszesen:      1.337
  200:      nincs adat
  500:      nincs adat

A legaktivabb IP a 193.224.41.77, ami az osszes keres 15.70%-at adta.
```

```text
$ ./hf05/logtool.sh --file access.log --quiet
A legaktivabb IP a 193.224.41.77, ami az osszes keres 18.27%-at adta.
```

Fájlba íráshoz például: `./hf05/logtool.sh -f access.log -o riport.txt`.
A bemeneti fájl nem adható meg kimenetként; hibás bemenet esetén a meglévő kimenet változatlan marad.
