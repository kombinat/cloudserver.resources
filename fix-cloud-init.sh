#!/bin/bash
# ============================================================
#  fix-cloud-init.sh
#  Behebt den cloud-init Versionskonflikt auf Ubuntu 22.04/24.04
#  (Downgrade auf Distro-native Version + einfrieren)
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Zielversionen pro Ubuntu-Release
declare -A TARGET_VERSIONS=(
    ["22.04"]="22.1-14-g2e17a0d6-0ubuntu1~22.04.5"
    ["24.04"]="24.1.3-0ubuntu3"
)

log()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
ok()     { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Root-Check
if [ "$EUID" -ne 0 ]; then
    error "Bitte als root ausführen: sudo bash fix-cloud-init.sh"
fi

# OS-Check und Zielversion bestimmen
DISTRO=$(lsb_release -rs 2>/dev/null || echo "unknown")
if [[ -n "${TARGET_VERSIONS[$DISTRO]+x}" ]]; then
    TARGET_VERSION="${TARGET_VERSIONS[$DISTRO]}"
else
    warn "Keine vordefinierte Version für Ubuntu $DISTRO"
    # Versuche die neueste Distro-Version aus dem Repo zu ermitteln
    apt-get update -qq 2>/dev/null
    TARGET_VERSION=$(apt-cache showpkg cloud-init 2>/dev/null \
        | awk '/^Versions:/{found=1; next} found && /^[0-9]/{print $1; exit}')
    if [ -z "$TARGET_VERSION" ]; then
        error "Konnte keine cloud-init Version im Repo finden für Ubuntu $DISTRO"
    fi
    warn "Verwende Repo-Version: $TARGET_VERSION"
    read -p "Fortfahren? (j/N): " confirm
    [[ "$confirm" =~ ^[jJyY]$ ]] || exit 0
fi

echo ""
echo "============================================================"
echo "  cloud-init Fix – Ubuntu $DISTRO"
echo "  Ziel-Version: $TARGET_VERSION"
echo "============================================================"
echo ""

# Schritt 1: Aktuelle Version anzeigen
log "Schritt 1/8: Aktuelle cloud-init Version prüfen..."
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

# Schritt 2: cloud-init systemd-Units demaskieren und aktivieren
log "Schritt 2/8: cloud-init systemd-Units prüfen..."
CLOUD_UNITS="cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service"
for unit in $CLOUD_UNITS; do
    if systemctl is-enabled "$unit" 2>/dev/null | grep -q "masked"; then
        systemctl unmask "$unit"
        log "$unit demaskiert"
    fi
done
# cloud-init.disabled-Datei entfernen, falls vorhanden
if [ -f /etc/cloud/cloud-init.disabled ]; then
    rm -f /etc/cloud/cloud-init.disabled
    log "/etc/cloud/cloud-init.disabled entfernt"
fi
for unit in $CLOUD_UNITS; do
    systemctl enable "$unit" 2>/dev/null || true
done
ok "cloud-init systemd-Units aktiv"

# Schritt 3: cloud-init entfernen
log "Schritt 3/8: cloud-init vollständig entfernen..."
# Hold aufheben, falls vom vorherigen Lauf vorhanden
if apt-mark showhold 2>/dev/null | grep -q "^cloud-init$"; then
    apt-mark unhold cloud-init
    log "Hold für cloud-init aufgehoben"
fi
apt-get remove --purge cloud-init -y -q
ok "cloud-init entfernt"

# Schritt 4: Python-Reste löschen
log "Schritt 4/8: Python-Reste und Cache bereinigen..."
rm -rf /usr/lib/python3/dist-packages/cloudinit
rm -rf /usr/local/lib/python3*/dist-packages/cloudinit
find /usr -name "*.pyc" -path "*cloudinit*" -delete 2>/dev/null || true
apt-get autoremove -y -q
apt-get clean -q
ok "Reste bereinigt"

# Schritt 5: Paketlisten aktualisieren
log "Schritt 5/8: Paketlisten aktualisieren..."
apt-get update -q
ok "Paketlisten aktuell"

# Schritt 6: Korrekte Version installieren
log "Schritt 6/8: cloud-init $TARGET_VERSION installieren..."
if ! apt-get install -y cloud-init="$TARGET_VERSION" -q; then
    error "Installation fehlgeschlagen – Version $TARGET_VERSION nicht verfügbar"
fi
ok "cloud-init $TARGET_VERSION installiert"

# Schritt 7: Datasource konfigurieren
log "Schritt 7/8: Datasource-Konfiguration prüfen..."
DS_CONFIG="/etc/cloud/cloud.cfg.d/90_dpkg.cfg"
if [ ! -f "$DS_CONFIG" ] || ! grep -q "datasource_list" "$DS_CONFIG" 2>/dev/null; then
    # Prüfe ob eine Datasource erkannt wird
    if ! cloud-init query platform 2>/dev/null | grep -qv "unknown"; then
        warn "Keine Datasource automatisch erkannt"
        # ConfigDrive ist Standard bei IONOS; Fallback auf NoCloud für bare-metal
        if blkid 2>/dev/null | grep -qi "config-2\|config_drive\|configdrive"; then
            log "ConfigDrive-Volume erkannt – verwende ConfigDrive"
            cat > /etc/cloud/cloud.cfg.d/99_datasource.cfg <<'EOF'
datasource_list: [ ConfigDrive, None ]
EOF
            ok "ConfigDrive-Datasource konfiguriert"
        else
            warn "Kein ConfigDrive-Volume gefunden – verwende NoCloud als Fallback"
            cat > /etc/cloud/cloud.cfg.d/99_datasource.cfg <<'EOF'
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    fs_label: cidata
EOF
            ok "NoCloud-Datasource konfiguriert"
        fi
    else
        ok "Datasource wird automatisch erkannt"
    fi
else
    ok "Datasource-Konfiguration vorhanden"
fi

# Schritt 8: Version einfrieren
log "Schritt 8/8: Version einfrieren (apt-mark hold)..."
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
