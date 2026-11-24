# Hibatűrő letöltő

```sh
./hf06/letoltő.sh hf06/urls.txt letoltesek
```

Az URL-listában soronként egy URL szerepel; az üres és `#`-tel kezdődő sorokat kihagyja. A célfájlok sorszámot kapnak, így azonos nevű végpontok sem ütköznek. Meglévő célfájlt nem ír felül. A napló a célkönyvtárban `letoltes.log` néven található; a program csak nem üres, teljesen letöltött fájlt helyez át oda.

- A `set -e` kezeletlen hibás parancsnál leállítja a scriptet.
- A `set -u` hibát jelez egy nem definiált változó használatakor.
- A `pipefail` miatt egy csővezeték sikertelen, ha bármelyik eleme hibázott, nem csak akkor, ha az utolsó.

A `curl` egy `if` feltételeként fut, így a várt letöltési hiba nem vált ki azonnali `set -e` kilépést. A hiba naplózása és legfeljebb három kísérlet után a következő URL következik. Három kísérlet között két szünet van: 1 és 2 másodperc; 4 másodperces várakozás csak egy negyedik kísérlet előtt lenne, amelyet a háromkísérletes korlát kizár. A célkönyvtárban létrehozott ideiglenes könyvtárat az `EXIT` trap törli, így az `mv` ugyanazon a fájlrendszeren dolgozik.

## Tesztfutás

Helyi HTTP-szerveren két sikeres és egy 500-as választ adó végponttal, majd külön Ctrl+C-próbával tesztelve:

```text
Sikeres: 2; sikertelen: 1
  Sikeres: http://127.0.0.1:65516/ok
  Sikeres: http://127.0.0.1:65516/ok2
  Sikertelen: http://127.0.0.1:65516/err: curl hibakód: 22; curl: (22) The requested URL returned error: 500
```

Részlet egy másik tényleges futás naplójából:

```text
[2026-11-24 08:51:19+0100] 2. URL: http://127.0.0.1:65380/bad; 1. próbálkozás
[2026-11-24 08:51:19+0100] Sikertelen próbálkozás: curl hibakód: 22; curl: (22) The requested URL returned error: 500
[2026-11-24 08:51:19+0100] Várakozás: 1s
[2026-11-24 08:51:20+0100] 2. URL: http://127.0.0.1:65380/bad; 2. próbálkozás
[2026-11-24 08:51:20+0100] Sikertelen próbálkozás: curl hibakód: 22; curl: (22) The requested URL returned error: 500
[2026-11-24 08:51:20+0100] Várakozás: 2s
[2026-11-24 08:51:22+0100] 2. URL: http://127.0.0.1:65380/bad; 3. próbálkozás
[2026-11-24 08:51:22+0100] Sikertelen próbálkozás: curl hibakód: 22; curl: (22) The requested URL returned error: 500
[2026-11-24 08:51:22+0100] Végleges hiba: http://127.0.0.1:65380/bad; curl hibakód: 22; curl: (22) The requested URL returned error: 500
[2026-11-24 08:51:22+0100] 3. URL: http://127.0.0.1:65380/good; 1. próbálkozás
[2026-11-24 08:51:22+0100] Siker: http://127.0.0.1:65380/good -> /private/var/folders/v6/260hrykd3hl_t6mqp_zjpyrc0000gn/T/tmpvjscatw1/out/0003-good
[2026-11-24 08:51:22+0100] Befejezve: siker=2, hiba=1.
```
