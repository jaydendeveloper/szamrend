# Napi jelentés

```sh
./hf09/napijelentes.sh --formatum szoveg
./hf09/napijelentes.sh --formatum json
./hf09/napijelentes.sh --frissits --formatum json
```

Függőségek: Bash, curl és jq. A cache a `${XDG_CACHE_HOME:-$HOME/.cache}/napijelentes` könyvtárban van; az érvényes, egy óránál frissebb válaszokat újra felhasználja. A `--frissits` mindegyik adatforrást újra lekérdezi. Az ünnepnapokat az aktuális és a következő évre is lekéri, hogy év végén is megtalálható legyen a következő ünnep.

Ha egy szolgáltatás nem érhető el vagy érvénytelen JSON-t ad, hibaüzenet kerül a standard hibakimenetre, az adott adatok `nem elérhető` értékkel, JSON-ban `null`-ként szerepelnek. A többi szolgáltatás eredménye megjelenik, de az exit kód nem nulla. Teljes hálózati hiba esetén is ugyanígy részletes hibát kapunk; friss cache mellett viszont hálózat nélkül is sikerülhet a jelentés. Az adat dátumát külön kiírja, így a hétvégi árfolyam régebbi dátuma látható.

Egy élő mérésben az üres cache-es első futás 0,303 s, a második, cache-t használó futás 0,050 s volt.

## Példakimenet: szöveg

```text
Napi jelentés: 2026-11-24
Árfolyam dátuma: 2026-11-23
1 EUR = 372.28 HUF; 1.0939 USD
Budapest ma (2026-11-24): min. 0.1, max. 3.8 °C
Budapest holnap (2026-11-25): min. -0.5, max. 2.2 °C
Következő ünnepnap: Karácsony (2026-12-25), 31 nap múlva
```

## Példakimenet: JSON

```json
{
	"keszult": "2026-11-24",
	"arfolyam": {
		"datum": "2026-11-23",
		"EUR_HUF": 372.28,
		"EUR_USD": 1.0939
	},
	"idojaras": {
		"ma": {
			"datum": "2026-11-24",
			"minimum": 0.1,
			"maximum": 3.8
		},
		"holnap": {
			"datum": "2026-11-25",
			"minimum": -0.5,
			"maximum": 2.2
		}
	},
	"kovetkezo_unnep": {
		"datum": "2026-12-25",
		"nev": "Karácsony",
		"napok_mulva": 31
	}
}
```
