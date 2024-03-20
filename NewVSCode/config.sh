# config.sh — single source of truth for the FinderZIP build.
#
# Sourced by scripts/build.sh. Edit values here; the scripts read from
# here so that adding a theme or renaming the app touches one file only.

APP_NAME="NewVSCode"

# Appearance variants to produce. Each becomes a FinderZIP_<variant>.app.
# To add a variant, add its name here and create src/icon/<variant>/
# (icon.json + master_1024.png), then add a case in icon_name_for().
VARIANTS=(light dark)

# variant -> catalog icon name baked into the .app
# (used for the .icon bundle name, actool --app-icon, and CFBundleIconName).
# Kept identical to the original project so nothing downstream breaks.
icon_name_for() {
  case "$1" in
    light) echo "Icon" ;;
    dark)  echo "Icon_dark" ;;
    *)     echo "Icon" ;;
  esac
}

# Icon Composer / actool settings
DEPLOY_TARGET="26.0"
DEV_REGION="en"

# --- Layout (relative to repo root; do not usually need to change) ---
SRC_DIR="src"
ICON_SRC_DIR="${SRC_DIR}/icon"          # FinderZIP.svg + <variant>/{icon.json,master_1024.png}
SHARED_SVG="${ICON_SRC_DIR}/icon.svg"
TEMPLATE_APP="app/${APP_NAME}.app"      # pristine Automator app (checked in)

BUILD_DIR="build"
ICNS_OUT="${BUILD_DIR}/icns"            # legacy .icns
ICON_OUT="${BUILD_DIR}/icon"            # assembled *.icon bundles
CAR_OUT="${BUILD_DIR}/car"              # compiled Assets.car (per variant)
APPS_OUT="${BUILD_DIR}/apps"            # final FinderZIP_<variant>.app

# Sizes for the legacy .icns iconset: "<pixels>:<filename>"
ICNS_SIZES=(
  "1024:icon_512x512@2x.png"
  "512:icon_512x512.png"
  "512:icon_256x256@2x.png"
  "256:icon_256x256.png"
  "256:icon_128x128@2x.png"
  "128:icon_128x128.png"
  "64:icon_32x32@2x.png"
  "32:icon_32x32.png"
  "32:icon_16x16@2x.png"
  "16:icon_16x16.png"
)
