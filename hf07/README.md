# Mentés és visszatöltés

```sh
./hf07/mentes.sh /abszolut/forras /abszolut/mentesek 7
./hf07/visszatoltes.sh /abszolut/mentesek
./hf07/visszatoltes.sh /abszolut/mentesek --legutobbi /abszolut/ures-cel --proba
./hf07/visszatoltes.sh /abszolut/mentesek --legutobbi /abszolut/ures-cel
```

A `--legutobbi` helyett konkrét `mentes-ÉÉÉÉ-HH-NN-ÓÓPP.tar.gz` név is megadható. A visszatöltés kizárólag létező, üres célkönyvtárba dolgozik; nem ír felül meglévő adatot. A `--proba` ellenőrzi a hash-t és kilistázza a tartalmat, de nem ír a célba. A fájlok ellenőrzőösszege SHA-256, macOS-en is elérhető `shasum -a 256` segítségével.

Az azonos percben elkészült második mentést a script nem írja felül. Az elavult, halott PID-re mutató zárolást megpróbálja eltávolítani; ha a PID nem olvasható vagy nem állapítható meg a folyamat állapota, biztonságból leáll, kézi ellenőrzés szükséges.

## Cron

Példa napi 3 órára; az útvonalakat a valódi abszolút útvonalakra kell cserélni:

```cron
0 3 * * * /abszolut/ut/hf07/mentes.sh /abszolut/forras /abszolut/mentesek 7
```

A felhasználó kérésére **nem lett cronfeladat telepítve**, ezért ez nem a `crontab -l` kimenete, és tényleges cronindulás nem lett igazolva. A script saját `PATH`-ot állít be, és az indítást a célkönyvtár `mentes.log` fájljába írja.

## Ellenőrzés

Tíz mentéssel, az archívumnevek és kísérőfájljaik kézi dátumozásával a hét legújabb maradt; külön teszt igazolta a párhuzamos zárolást, üres célba történő visszatöltést és a nem író próbát.

Tényleges naplórészlet:

```text
[2026-11-24 08:51:19+0100] Mentés indítása.
[2026-11-24 08:51:19+0100] Archívum készítése: /private/var/folders/v6/260hrykd3hl_t6mqp_zjpyrc0000gn/T/tmp0uydh55t/source -> mentes-2026-11-24-0851.tar.gz.
[2026-11-24 08:51:19+0100] Mentés kész: mentes-2026-11-24-0851.tar.gz, 529 bájt, 2 fájl.
[2026-11-24 08:51:19+0100] Retenció törölte: mentes-2025-01-03-1200.tar.gz.
```

Egy bájttal módosított archívum visszatöltésének hibakimenete:

```text
Hiba: az ellenőrzőösszeg nem egyezik; visszatöltés megtagadva.
```
