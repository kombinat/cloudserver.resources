#!/bin/bash
# ============================================================
#  fix-cloud-init.sh
#  Behebt den cloud-init Versionskonflikt auf Ubuntu 22.04
#  (Downgrade von 25.3 auf 22.1 + Version einfrieren)
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET_VERSION="22.1-14-g2e17a0d6-0ubuntu1~22.04.5"

log()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
ok()     { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "============================================================"
echo "  cloud-init Fix – Ubuntu 22.04"
echo "  Ziel-Version: $TARGET_VERSION"
echo "============================================================"
echo ""

# Root-Check
if [ "$EUID" -ne 0 ]; then
    error "Bitte als root ausführen: sudo bash fix-cloud-init.sh"
fi

# OS-Check
DISTRO=$(lsb_release -rs 2>/dev/null || echo "unknown")
if [ "$DISTRO" != "22.04" ]; then
    warn "Dieses Script ist für Ubuntu 22.04 – erkannte Version: $DISTRO"
    read -p "Trotzdem fortfahren? (j/N): " confirm
    [[ "$confirm" =~ ^[jJyY]$ ]] || exit 0
fi

# Schritt 1: Aktuelle Version anzeigen
log "Schritt 1/6: Aktuelle cloud-init Version prüfen..."
CURRENT=$(dpkg -l cloud-init 2>/dev/null | awk '/^[hi]i/{print $3}' || echo "nicht installiert")
echo "  Installiert: $CURRENT"
echo "  Ziel:        $TARGET_VERSION"
echo ""

if [ "$CURRENT" = "$TARGET_VERSION" ]; then
    # Sicherstellen dass der Hold gesetzt ist
    if ! apt-mark showhold 2>/dev/null | grep -q "^cloud-init$"; then
        apt-mark hold cloud-init
        warn "Hold war nicht gesetzt – wurde nachgetragen"
    fi
    ok "Korrekte Version bereits installiert und eingefroren – kein Eingriff nötig."
    exit 0
fi

# Schritt 2: cloud-init entfernen
log "Schritt 2/6: cloud-init vollständig entfernen..."
# Hold aufheben, falls vom vorherigen Lauf vorhanden
if apt-mark showhold 2>/dev/null | grep -q "^cloud-init$"; then
    apt-mark unhold cloud-init
    log "Hold für cloud-init aufgehoben"
fi
apt-get remove --purge cloud-init -y -q
ok "cloud-init entfernt"

# Schritt 3: Python-Reste löschen
log "Schritt 3/6: Python-Reste und Cache bereinigen..."
rm -rf /usr/lib/python3/dist-packages/cloudinit
rm -rf /usr/local/lib/python3*/dist-packages/cloudinit
find /usr -name "*.pyc" -path "*cloudinit*" -delete 2>/dev/null || true
apt-get autoremove -y -q
apt-get clean -q
ok "Reste bereinigt"

# Schritt 4: Paketlisten aktualisieren
log "Schritt 4/6: Paketlisten aktualisieren..."
apt-get update -q
ok "Paketlisten aktuell"

# Schritt 5: Korrekte Version installieren
log "Schritt 5/6: cloud-init $TARGET_VERSION installieren..."
if ! apt-get install -y cloud-init="$TARGET_VERSION" -q; then
    error "Installation fehlgeschlagen – Version $TARGET_VERSION nicht verfügbar"
fi
ok "cloud-init $TARGET_VERSION installiert"

# Schritt 6: Version einfrieren
log "Schritt 6/6: Version einfrieren (apt-mark hold)..."
apt-mark hold cloud-init
ok "cloud-init wird nicht mehr automatisch aktualisiert"

# Ergebnis testen
echo ""
echo "============================================================"
echo "  Teste Installation..."
echo "============================================================"

# Python-Import testen
if python3 -c "from cloudinit.log import getLogger; print('Python-Import: OK')" 2>/dev/null; then
    ok "Python-Modul cloudinit.log.getLogger ist erreichbar"
else
    error "Python-Import fehlgeschlagen – bitte Logs prüfen"
fi

# cloud-init neu initialisieren
log "cloud-init zurücksetzen und neu initialisieren..."
cloud-init clean --logs
cloud-init init 2>/dev/null || true

# Finaler Status
echo ""
echo "============================================================"
echo "  Finaler Status"
echo "============================================================"
cloud-init status --long

echo ""
echo "============================================================"
INSTALLED=$(dpkg -l cloud-init | awk '/^[hi]i/{print $3}')
HELD=$(apt-mark showhold | grep cloud-init || echo "")
if [ "$HELD" = "cloud-init" ]; then
    ok "cloud-init $INSTALLED ist installiert und eingefroren"
    echo ""
    echo "  Fertig! Um den Hold später aufzuheben:"
    echo "  sudo apt-mark unhold cloud-init"
else
    warn "cloud-init ist installiert aber NICHT eingefroren"
fi
echo "============================================================"
echo ""
