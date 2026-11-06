#!/usr/bin/env bash
# Zu Uebung 01.1. Schaltet den Zustand der SIMULIERTEN USV um (schreibt die .dev-Datei neu).
# Aufruf als root:  sudo bash 01.1-usv-zustand.sh <netz|ausfall|schwach>
#   netz     Netzbetrieb:                  OL,    100 %, 1800 s Restlaufzeit
#   ausfall  Batteriebetrieb:              OB,     90 %, 1500 s
#   schwach  Batteriebetrieb, Batterie schwach: OB LB, 10 %, 120 s  (loest das Herunterfahren sofort aus)
# Optional: USV_NAME, CONF_DIR als Umgebungsvariablen. Der Treiber liest die Datei neu, sobald sich ihr Zeitstempel aendert.
set -euo pipefail
USV_NAME="${USV_NAME:-buero-usv}"
CONF_DIR="${CONF_DIR:-/etc/nut}"
DATEI="$CONF_DIR/${USV_NAME}.dev"

[ "$(id -u)" -eq 0 ] || { echo "Bitte als root ausfuehren (sudo)." >&2; exit 1; }
[ -f "$DATEI" ] || { echo "Datei nicht gefunden: $DATEI (erst 01.1-nut-server.sh ausfuehren)." >&2; exit 1; }

case "${1:-}" in
    netz)    STATUS="OL";    LADUNG=100; LAUFZEIT=1800 ;;
    ausfall) STATUS="OB";    LADUNG=90;  LAUFZEIT=1500 ;;
    schwach) STATUS="OB LB"; LADUNG=10;  LAUFZEIT=120  ;;
    *) echo "Aufruf: $0 <netz|ausfall|schwach>" >&2; exit 1 ;;
esac

TMP="$(mktemp "${DATEI}.XXXXXX")"
cat > "$TMP" <<EOF
ups.mfr: Simulation
ups.model: Dummy-USV Uebung
ups.status: ${STATUS}
battery.charge: ${LADUNG}
battery.runtime: ${LAUFZEIT}
ups.load: 35
EOF
chmod --reference="$DATEI" "$TMP"
chown --reference="$DATEI" "$TMP" 2>/dev/null || true
mv "$TMP" "$DATEI"
echo "Zustand gesetzt: ${1} (ups.status: ${STATUS})"
sleep 3
upsc "${USV_NAME}@localhost" ups.status 2>/dev/null | sed 's/^/Treiber meldet: /' || echo "(upsc nicht erreichbar, laeuft upsd?)"
