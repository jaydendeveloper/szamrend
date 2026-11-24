# HF10 — PowerShell: objektumok és riport

## 1. Felfedezés

Az első két darabszám a PowerShell verziójától, a betöltött moduloktól és
az operációs rendszertől is függ. A készítéskor nem állt rendelkezésre
`pwsh`, ezért ezeket a saját gépen kell lemérni; nem megfigyelt értéket
nem adok meg.

1. A `Get-Command *Process*` találatai közül ennyinek kezdődik a neve
   `Get-`-tel:

   ```powershell
   @(Get-Command *Process* -CommandType Cmdlet |
       Where-Object Name -like 'Get-*').Count
   ```

   Ha a kérdés az összes elérhető `Get-` cmdletre vonatkozik, nem csak a
   `Process` nevűekre: `@(Get-Command Get-* -CommandType Cmdlet).Count`.

2. A `Get-Process` objektumok property-jeinek száma:

   ```powershell
   @(Get-Process | Get-Member -MemberType Properties).Count
   ```

   A `Properties` a különféle property-típusokat is számolja; a metódusokat nem.

3. CSV beolvasása: `Import-Csv`; JSON szöveg objektummá alakítása:
   `ConvertFrom-Json`. Keresésük például:

   ```powershell
   Get-Command *csv*
   Get-Command *json*
   ```

4. A `Format-Table` nem a folyamatobjektumokat adja tovább, hanem
   formázási objektumokat. Ezért a formázás utáni `Where-Object` már nem
   a folyamatok `Id` tulajdonságát látja. A második változat előbb az
   eredeti objektumokat szűri, csak utána formázza az eredményt. A
   `Format-Table` ezért általában a pipeline végére való.

5. `"9" -lt "65"` eredménye `False`: a bal oldal string, ezért az
   összehasonlítás szöveges, és a `9` a `6` után következik. A
   `[int]"9" -lt 65` eredménye `True`, mert ez már a 9 és 65 számok
   összehasonlítása.

## 2. Logriport

A script a HF4 generátorának 11 mezős logformátumát olvassa. A `-Status`
szűrés minden statisztikára érvényes; a `-Top` a legtöbb kérést küldő
IP-k számát korlátozza. Az órák a logban szereplő időt követik, időzóna-
átváltás nélkül. A hibás sor vagy olvashatatlan fájl hiba, nem részleges
riport. A `-Csendes` csak az összefoglaló objektumot adja vissza.

Minden sor azonos mezőket tartalmaz, így a teljes riport egyetlen CSV-be
is exportálható:

- `Tipus`: `Osszesen`, `IP`, `Status`, `HibasURL` vagy `Ora`.
- `Kulcs`: az összefoglalóban a legaktívabb IP, egyébként a csoport IP-je,
  szám típusú státusza, URL-je vagy `DateTime` típusú órája.
- `Keresek`: egész szám; `Arany`: százalék számként, nem formázott szövegként.
  Az összefoglalóban az arány a legaktívabb IP aránya.
- `EgyediIP`, `AtlagValaszido`, `Atlag200`, `Atlag500`: az összefoglaló
  adatai. A válaszidők másodpercben értendők.
- `Csucs`: az órás sorban logikai érték; minden holtversenyes csúcs `True`.

A nem alkalmazható mezők `$null` értékűek. Üres bemenet vagy eredmény nélküli
szűrés esetén egy nulla kérést tartalmazó összefoglaló keletkezik;
ilyenkor nincs legaktívabb IP vagy átlagos válaszidő.

```powershell
Get-Help ./hf10/Get-LogRiport.ps1 -Examples
./hf10/Get-LogRiport.ps1 -Path access.log | Format-Table
./hf10/Get-LogRiport.ps1 -Path access.log |
    Sort-Object Keresek -Descending | Select-Object -First 3
./hf10/Get-LogRiport.ps1 -Path access.log | Export-Csv riport.csv -NoTypeInformation
./hf10/Get-LogRiport.ps1 -Path access.log | ConvertTo-Json -Depth 4
./hf10/Get-LogRiport.ps1 -Path access.log | Where-Object { $_.Keresek -gt 100 }
./hf10/Get-LogRiport.ps1 -Path access.log -Status 404 -Top 3 -Csendes
```

Az összefoglaló és a különböző csoportosítások számai ugyanazokat a
kéréseket különböző nézetekben mutatják: a sorok `Keresek` mezőit nem
szabad egymással összeadni. Egyetlen nézet például
`Where-Object Tipus -eq 'IP'` szűréssel választható ki. Az `Import-Csv`
visszaolvasáskor minden mezőt stringgé alakít, ezért számszerű rendezéshez
vissza kell alakítani a megfelelő mezőt.

## Bashhez képest

Számomra az objektumos pipeline a legérdekesebb különbség: ugyanazt a
riportot külön szövegfeldolgozás nélkül lehet szűrni, rendezni, táblázatként
megjeleníteni vagy CSV-be, illetve JSON-ba exportálni. A formázás viszont
lezárja ezt az objektumos feldolgozást, ezért a helye a pipeline végén van.
