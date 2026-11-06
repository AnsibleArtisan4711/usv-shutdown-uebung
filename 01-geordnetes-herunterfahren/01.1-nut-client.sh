#!/usr/bin/env bash
# Zu Uebung 01.1 (Geordnetes Herunterfahren ohne USV).
# Richtet auf einer zweiten Debian-/Ubuntu-VM einen NUT-Client (secondary) ein: Er fragt den NUT-Server ab
# und faehrt sich herunter, sobald der Server das Herunterfahren verlangt.
# Standardmaessig im Probemodus (nur protokollieren). Mit  USV_ECHT=1  faehrt die VM wirklich herunter.
# Aufruf als root:  sudo SERVER=192.168.50.10 bash 01.1-nut-client.sh
# Optionen: SERVER (Pflicht, Adresse des NUT-Servers), USV_NAME (buero-usv), USV_ECHT (0)
set -euo pipefail

SERVER="${SERVER:-}"
USV_NAME="${USV_NAME:-buero-usv}"
USV_ECHT="${USV_ECHT:-0}"
CONF_DIR="${CONF_DIR:-/etc/nut}"
BIN_DIR="${BIN_DIR:-/usr/local/sbin}"
LOG_FILE="${LOG_FILE:-/var/log/usv-uebung.log}"
CLIENT_USER="usvclient"
MARKER="# --- Uebung 01.1 ---"
PAKETE_INSTALLIEREN="${PAKETE_INSTALLIEREN:-1}"
DIENSTE_STARTEN="${DIENSTE_STARTEN:-1}"

if [ "$(id -u)" -ne 0 ]; then echo "Bitte als root ausfuehren (sudo)." >&2; exit 1; fi
[ -n "$SERVER" ] || { echo "Bitte SERVER=<Adresse> angeben, zum Beispiel: sudo SERVER=192.168.50.10 bash $0" >&2; exit 1; }
case "$SERVER$USV_NAME" in *[!A-Za-z0-9_.-]*) echo "SERVER und USV_NAME: nur Buchstaben, Ziffern, ., _ und -." >&2; exit 1 ;; esac

if [ "$PAKETE_INSTALLIEREN" = "1" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq nut-client
fi
mkdir -p "$CONF_DIR" "$BIN_DIR"
if grep -qF "$MARKER" "$CONF_DIR/upsmon.conf" 2>/dev/null; then
    echo "Schon eingerichtet (Marker gefunden). Nichts geaendert."; exit 0
fi

read -r -s -p "Kennwort fuer ${CLIENT_USER} (wie auf dem Server vergeben): " PW; echo
case "$PW" in ''|*[[:space:]\"\\#]*) echo "Kennwort leer oder enthaelt unzulaessige Zeichen." >&2; exit 1 ;; esac

for f in nut.conf upsmon.conf; do [ -f "$CONF_DIR/$f" ] && cp -n "$CONF_DIR/$f" "$CONF_DIR/$f.vor-uebung"; done
printf 'MODE=netclient\n' > "$CONF_DIR/nut.conf"
umask 027
cat >> "$CONF_DIR/upsmon.conf" <<EOF

${MARKER}
MONITOR ${USV_NAME}@${SERVER} 1 ${CLIENT_USER} ${PW} secondary
MINSUPPLIES 1
SHUTDOWNCMD "${BIN_DIR}/usv-herunterfahren.sh"
EOF
unset PW
chmod 640 "$CONF_DIR/upsmon.conf"
chgrp nut "$CONF_DIR/upsmon.conf" 2>/dev/null || true
umask 022

cat > "${BIN_DIR}/usv-herunterfahren.sh" <<EOF
#!/bin/sh
# Wird von upsmon als SHUTDOWNCMD aufgerufen.
echo "\$(date '+%F %T') SHUTDOWNCMD ausgefuehrt auf \$(hostname)" >> "${LOG_FILE}"
if [ -f "${CONF_DIR}/usv-echt" ]; then
    /sbin/shutdown -h +0 "USV: geordnetes Herunterfahren"
else
    echo "\$(date '+%F %T') Probemodus: es wird NICHT heruntergefahren" >> "${LOG_FILE}"
fi
EOF
chmod 755 "${BIN_DIR}/usv-herunterfahren.sh"
[ "$USV_ECHT" = "1" ] && touch "$CONF_DIR/usv-echt"
touch "$LOG_FILE"

if [ "$DIENSTE_STARTEN" = "1" ]; then
    systemctl enable nut-monitor >/dev/null 2>&1 || true
    systemctl restart nut-monitor
fi
echo "Fertig. Pruefen:  upsc ${USV_NAME}@${SERVER}   und   tail -f ${LOG_FILE}"
