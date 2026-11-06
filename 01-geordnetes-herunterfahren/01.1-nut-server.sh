#!/usr/bin/env bash
# Zu Uebung 01.1 (Geordnetes Herunterfahren ohne USV).
# Richtet auf einer Debian- oder Ubuntu-VM einen NUT-Server mit einer SIMULIERTEN USV ein (Treiber dummy-ups):
#  - Zustand der USV steht in einer Textdatei (/etc/nut/<USV-Name>.dev) und wird mit 01.1-usv-zustand.sh umgeschaltet
#  - upsd stellt die USV im Netz bereit, upsmon (primary) ueberwacht sie
#  - upssched wartet nach Beginn des Batteriebetriebs eine einstellbare Zeit, bevor das Herunterfahren ausgeloest wird
#  - das Herunterfahren selbst laeuft ueber /usr/local/sbin/usv-herunterfahren.sh: im Probemodus (Standard)
#    wird nur protokolliert, mit  USV_ECHT=1  (oder spaeter: Datei <CONF_DIR>/usv-echt anlegen) faehrt die VM wirklich herunter
# Kennwoerter werden abgefragt (mindestens 8 Zeichen) und stehen nicht im Skript.
# Aufruf als root:  sudo bash 01.1-nut-server.sh
# Optionen als Umgebungsvariablen: USV_NAME (buero-usv), VERZOEGERUNG (Sekunden bis zum Herunterfahren, 180),
#   HOSTSYNC (Sekunden Wartezeit auf Clients, 30), LISTEN_ADDR (0.0.0.0), USV_ECHT (0)
set -euo pipefail

USV_NAME="${USV_NAME:-buero-usv}"
VERZOEGERUNG="${VERZOEGERUNG:-180}"
HOSTSYNC="${HOSTSYNC:-30}"
LISTEN_ADDR="${LISTEN_ADDR:-0.0.0.0}"
USV_ECHT="${USV_ECHT:-0}"
CONF_DIR="${CONF_DIR:-/etc/nut}"
BIN_DIR="${BIN_DIR:-/usr/local/sbin}"
LOG_FILE="${LOG_FILE:-/var/log/usv-uebung.log}"
STATE_DIR="${STATE_DIR:-/run/nut}"
PRIMARY_USER="usvprimaer"
CLIENT_USER="usvclient"
MARKER="# --- Uebung 01.1 ---"
PAKETE_INSTALLIEREN="${PAKETE_INSTALLIEREN:-1}"
DIENSTE_STARTEN="${DIENSTE_STARTEN:-1}"

if [ "$(id -u)" -ne 0 ]; then echo "Bitte als root ausfuehren (sudo)." >&2; exit 1; fi
case "$USV_NAME" in *[!A-Za-z0-9_-]*|'') echo "USV_NAME: nur Buchstaben, Ziffern, _ und -." >&2; exit 1 ;; esac
case "$VERZOEGERUNG$HOSTSYNC" in *[!0-9]*|'') echo "VERZOEGERUNG und HOSTSYNC muessen ganze Zahlen sein." >&2; exit 1 ;; esac

frage_kennwort() {
    local frage="$1" a b
    while true; do
        read -r -s -p "$frage: " a; echo
        if [ "${#a}" -lt 8 ]; then echo "    Mindestens 8 Zeichen."; continue; fi
        case "$a" in *[[:space:]\"\\#]*) echo "    Keine Leerzeichen, Anfuehrungszeichen, # oder Backslash."; continue ;; esac
        read -r -s -p "    Zur Kontrolle nochmal: " b; echo
        [ "$a" = "$b" ] && { REPLY_PW="$a"; return; }
        echo "    Eingaben unterschiedlich."
    done
}

if [ "$PAKETE_INSTALLIEREN" = "1" ]; then
    echo "1/6 Pakete installieren (nut)"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq nut
else
    echo "1/6 Paketinstallation uebersprungen"
fi
mkdir -p "$CONF_DIR" "$BIN_DIR"

if grep -qF "$MARKER" "$CONF_DIR/upsmon.conf" 2>/dev/null; then
    echo "Schon eingerichtet (Marker in upsmon.conf gefunden). Nichts geaendert." ; exit 0
fi

echo "2/6 Kennwoerter fuer die NUT-Konten"
frage_kennwort "Kennwort fuer ${PRIMARY_USER} (dieser Server)"; PW_PRIMARY="$REPLY_PW"
frage_kennwort "Kennwort fuer ${CLIENT_USER} (die Clients)"; PW_CLIENT="$REPLY_PW"

echo "3/6 Simulierte USV ${USV_NAME} anlegen"
for f in nut.conf ups.conf upsd.conf upsd.users upsmon.conf upssched.conf; do
    [ -f "$CONF_DIR/$f" ] && cp -n "$CONF_DIR/$f" "$CONF_DIR/$f.vor-uebung"
done
printf 'MODE=netserver\n' > "$CONF_DIR/nut.conf"
cat > "$CONF_DIR/${USV_NAME}.dev" <<EOF
ups.mfr: Simulation
ups.model: Dummy-USV Uebung
ups.status: OL
battery.charge: 100
battery.runtime: 1800
ups.load: 35
EOF
cat >> "$CONF_DIR/ups.conf" <<EOF

${MARKER}
[${USV_NAME}]
    driver = dummy-ups
    port = ${USV_NAME}.dev
    desc = "Simulierte USV (Uebung 01.1)"
EOF
printf '\n%s\nLISTEN %s 3493\n' "$MARKER" "$LISTEN_ADDR" >> "$CONF_DIR/upsd.conf"

echo "4/6 Konten und Ueberwachung"
umask 027
cat >> "$CONF_DIR/upsd.users" <<EOF

${MARKER}
[${PRIMARY_USER}]
    password = ${PW_PRIMARY}
    upsmon primary

[${CLIENT_USER}]
    password = ${PW_CLIENT}
    upsmon secondary
EOF
cat >> "$CONF_DIR/upsmon.conf" <<EOF

${MARKER}
MONITOR ${USV_NAME}@localhost 1 ${PRIMARY_USER} ${PW_PRIMARY} primary
MINSUPPLIES 1
SHUTDOWNCMD "${BIN_DIR}/usv-herunterfahren.sh"
HOSTSYNC ${HOSTSYNC}
NOTIFYCMD /usr/sbin/upssched
NOTIFYFLAG ONBATT SYSLOG+WALL+EXEC
NOTIFYFLAG ONLINE SYSLOG+WALL+EXEC
EOF
unset PW_PRIMARY PW_CLIENT
chmod 640 "$CONF_DIR/upsd.users" "$CONF_DIR/upsmon.conf"
chgrp nut "$CONF_DIR/upsd.users" "$CONF_DIR/upsmon.conf" "$CONF_DIR/${USV_NAME}.dev" 2>/dev/null || true
chmod 664 "$CONF_DIR/${USV_NAME}.dev"
umask 022

echo "5/6 Verzoegerung (${VERZOEGERUNG} s auf Batterie) und Herunterfahr-Skript"
cat >> "$CONF_DIR/upssched.conf" <<EOF

${MARKER}
CMDSCRIPT ${BIN_DIR}/usv-ereignis.sh
PIPEFN ${STATE_DIR}/upssched.pipe
LOCKFN ${STATE_DIR}/upssched.lock
AT ONBATT * START-TIMER ausfall-lang ${VERZOEGERUNG}
AT ONLINE * CANCEL-TIMER ausfall-lang
EOF
cat > "${BIN_DIR}/usv-ereignis.sh" <<EOF
#!/bin/sh
# Wird von upssched aufgerufen. Argument: Name des Timers.
case "\$1" in
    ausfall-lang)
        MELDUNG="Stromausfall dauert laenger als ${VERZOEGERUNG} s, Herunterfahren wird ausgeloest"
        echo "\$(date '+%F %T') \$MELDUNG" >> "${LOG_FILE}"
        logger -t usv-uebung "\$MELDUNG"
        /usr/sbin/upsmon -c fsd
        ;;
esac
EOF
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
chmod 755 "${BIN_DIR}/usv-ereignis.sh" "${BIN_DIR}/usv-herunterfahren.sh"
[ "$USV_ECHT" = "1" ] && touch "$CONF_DIR/usv-echt"
touch "$LOG_FILE"
# upssched laeuft als Benutzer nut und muss das Protokoll beschreiben koennen
chgrp nut "$LOG_FILE" 2>/dev/null || true
chmod 664 "$LOG_FILE"

if [ "$DIENSTE_STARTEN" = "1" ]; then
    echo "6/6 Dienste starten"
    systemctl enable nut-server nut-monitor >/dev/null 2>&1 || true
    systemctl restart nut-driver.target nut-server nut-monitor 2>/dev/null || {
        upsdrvctl start; systemctl restart nut-server nut-monitor; }
else
    echo "6/6 Dienste starten uebersprungen"
fi
echo
echo "Fertig. Pruefen:  upsc ${USV_NAME}@localhost"
echo "Zustand umschalten:  sudo bash 01.1-usv-zustand.sh ausfall   (netz | ausfall | schwach)"
echo "Protokoll:  tail -f ${LOG_FILE}"
