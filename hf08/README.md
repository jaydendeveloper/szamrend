# Logtool Dockerben

A Debian bookworm-slim tartalmazza a riporthoz szükséges Bash, awk és alapvető Unix parancsokat; további csomag nem szükséges.

```sh
cd hf08
docker build -t logtool:1.0 .
docker run --rm logtool:1.0 --help
docker run --rm -v "$PWD/adatok:/adatok:ro" logtool:1.0 -f /adatok/access.log -t 5
docker run --rm --entrypoint whoami logtool:1.0
docker images logtool:1.0
```

Az `adatok/access.log` legyen olvasható a konténer nem root felhasználója számára. A `:ro` megakadályozza, hogy a konténer módosítsa a csatolt bemeneti könyvtárat. Tartós kimenethez külön írható kötet szükséges.

A felhasználó létrehozása a script másolása előtt történik, ezért a script módosítása nem érvényteleníti ezt a réteget. Itt nincs csomagtelepítés, így annak rétege sem épül újra. Rossz sorrendben a `COPY . .` után szereplő `RUN` réteg egy scriptmódosításkor is újraépülne.

Az első build, a jó sorrendű újrabuild és a rossz sorrendű újrabuild ideje **nem mérhető ebben a környezetben**, mert Docker nem áll rendelkezésre. Az image mérete és a konténeres futás emiatt szintén nincs ellenőrizve.
