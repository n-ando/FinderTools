#!/usr/bin/env bash
#
# build.sh — rebuild NewMD icons and app variants from a single source.
#
#   ./scripts/build.sh all          # icns -> icon -> car -> apps (default)
#   ./scripts/build.sh icns         # master_1024.png -> build/icns/<variant>.icns
#   ./scripts/build.sh icon         # src/icon/<variant> -> build/icon/<Name>.icon
#   ./scripts/build.sh car          # build/icon/*.icon -> build/car/<variant>/Assets.car
#   ./scripts/build.sh apps         # template + icons -> build/apps/NewMD_<variant>.app
#   ./scripts/build.sh clean        # remove build/
#   ./scripts/build.sh cache-reset  # restart Dock & Finder to flush the icon cache
#
# Edit values in config.sh, not here.

set -euo pipefail

# --- locate repo root regardless of where we are invoked from ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$ROOT"
# shellcheck source=../config.sh
source "${ROOT}/config.sh"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

require() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found (this step needs macOS)."; }

# ---------------------------------------------------------------------------
# icns: master_1024.png -> .iconset (sips) -> .icns (iconutil)
# ---------------------------------------------------------------------------
build_icns() {
  require sips; require iconutil
  mkdir -p "$ICNS_OUT"
  for v in "${VARIANTS[@]}"; do
    local master="${ICON_SRC_DIR}/${v}/master_1024.png"
    [ -f "$master" ] || die "missing master image: $master"
    local iconset="${ICNS_OUT}/${v}.iconset"
    rm -rf "$iconset"; mkdir -p "$iconset"
    log "icns: ${v} (from $(basename "$master"))"
    for entry in "${ICNS_SIZES[@]}"; do
      sips -Z "${entry%%:*}" "$master" --out "${iconset}/${entry##*:}" >/dev/null
    done
    iconutil -c icns "$iconset" -o "${ICNS_OUT}/${v}.icns"
    rm -rf "$iconset"   # the .iconset is an intermediate; keep only the .icns
  done
}

# ---------------------------------------------------------------------------
# icon: assemble Icon Composer bundles from shared SVG + per-variant icon.json
# ---------------------------------------------------------------------------
build_icon() {
  [ -f "$SHARED_SVG" ] || die "missing shared SVG: $SHARED_SVG"
  mkdir -p "$ICON_OUT"
  for v in "${VARIANTS[@]}"; do
    local json="${ICON_SRC_DIR}/${v}/icon.json"
    [ -f "$json" ] || die "missing icon.json: $json"
    local name; name="$(icon_name_for "$v")"
    local bundle="${ICON_OUT}/${name}.icon"
    log "icon: ${v} -> ${name}.icon"
    rm -rf "$bundle"; mkdir -p "${bundle}/Assets"
    cp "$json"        "${bundle}/icon.json"
    cp "$SHARED_SVG"  "${bundle}/Assets/$(basename "$SHARED_SVG")"
  done
}

# ---------------------------------------------------------------------------
# car: compile each .icon bundle into an Assets.car via actool
# ---------------------------------------------------------------------------
build_car() {
  require actool
  for v in "${VARIANTS[@]}"; do
    local name; name="$(icon_name_for "$v")"
    local bundle="${ICON_OUT}/${name}.icon"
    [ -d "$bundle" ] || die "missing .icon bundle: $bundle (run 'icon' first)"
    local out="${CAR_OUT}/${v}"
    rm -rf "$out"; mkdir -p "$out"
    log "car: ${name}.icon -> ${out}/Assets.car"
    actool "$bundle" --compile "$out" \
      --output-format human-readable-text --notices --warnings --errors \
      --output-partial-info-plist "${out}/partial.plist" \
      --app-icon "$name" --include-all-app-icons \
      --enable-on-demand-resources NO \
      --development-region "$DEV_REGION" \
      --target-device mac \
      --minimum-deployment-target "$DEPLOY_TARGET" \
      --platform macosx
    rm -f "${out}/partial.plist"   # by-product, not needed
  done
}

# ---------------------------------------------------------------------------
# apps: duplicate the template app and install both icon styles
# ---------------------------------------------------------------------------
build_apps() {
  require plutil
  [ -d "$TEMPLATE_APP" ] || die "missing template app: $TEMPLATE_APP"
  mkdir -p "$APPS_OUT"
  for v in "${VARIANTS[@]}"; do
    local name; name="$(icon_name_for "$v")"
    local app="${APPS_OUT}/${APP_NAME}_${v}.app"
    local res="${app}/Contents/Resources"
    local icns="${ICNS_OUT}/${v}.icns"
    local car="${CAR_OUT}/${v}/Assets.car"
    [ -f "$icns" ] || die "missing $icns (run 'icns' first)"
    [ -f "$car"  ] || die "missing $car (run 'car' first)"

    log "app:  ${APP_NAME}_${v}.app (icon=${name})"
    rm -rf "$app"
    cp -R "$TEMPLATE_APP" "$app"

    cp "$icns" "${res}/ApplicationStub.icns"   # legacy / fallback icon
    cp "$car"  "${res}/Assets.car"             # modern Liquid Glass icon
    plutil -replace CFBundleIconName -string "$name" "${app}/Contents/Info.plist"
    touch "$app"                               # nudge LaunchServices/Finder
  done
}

build_icons_only() { build_icns; build_icon; build_car; }
build_all() { build_icns; build_icon; build_car; build_apps; log "Done. Output in ${APPS_OUT}/"; }

clean() { log "removing ${BUILD_DIR}/"; rm -rf "$BUILD_DIR"; }

cache_reset() {
  if [ -e /dev/tty ]; then
    read -r -p "Restart Dock and Finder to clear the icon cache? [y/N]: " ans < /dev/tty
  else
    ans="n"
  fi
  case "$ans" in
    [yY]|[yY][eE][sS]) killall Dock Finder ;;
    *) log "Skipped." ;;
  esac
}

usage() { sed -n '3,13{s/^#\{1,1\} \{0,1\}//;p;}' "$0"; }

case "${1:-all}" in
  all)         build_all ;;
  icons)       build_icons_only ;;
  icns)        build_icns ;;
  icon)        build_icon ;;
  car)         build_car ;;
  apps)        build_apps ;;
  clean)       clean ;;
  cache-reset) cache_reset ;;
  -h|--help|help) usage ;;
  *) die "unknown command: $1 (try --help)" ;;
esac
