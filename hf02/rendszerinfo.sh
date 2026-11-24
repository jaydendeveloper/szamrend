#!/usr/bin/env bash

collect_sys_info() {
    echo "=== Rendszerinformációk ==="
    
    echo "[Gépnév]"
    hostname
    
    echo -e "\n[Kernel verzió]"
    uname -r
    
    echo -e "\n[Uptime]"
    uptime
    
    echo -e "\n[Jelenlegi felhasználó]"
    whoami
    
    echo -e "\n[Home könyvtár mérete]"
    du -sh "$HOME" 2>/dev/null
    
    echo -e "\n[Gyökér fájlrendszer (df -h /)]"
    df -h /
    
    echo -e "\n[Futó folyamatok száma]"
    ps -e | wc -l
    
    echo "==========================="
}

DEST="$1"

if [ -n "$DEST" ]; then
    if ! collect_sys_info > "$DEST" 2>/dev/null; then
        echo "Hiba: Nem sikerült írni a megadott célfájlba ($DEST)." >&2
        exit 1
    fi
else
    collect_sys_info
fi

exit 0
