#!/bin/bash

# Finder Shrink - Automator shell step, v2.
#
# Automator settings:
#   Shell: /bin/bash
#   Pass input: as arguments
#
# This version deliberately exits with status 0 after logging. Otherwise Automator
# can show an unhelpful error dialog such as: error: "".

if [ -z "${BASH_VERSION:-}" ]; then
    if [ -x /usr/bin/osascript ]; then
        /usr/bin/osascript -e 'display dialog "Finder Shrink: Automatorの「シェルスクリプトを実行」アクションで、シェルを /bin/bash に変更してください。シェバン行だけではAutomatorの実行シェルは変わりません。" buttons {"OK"} default button "OK" with icon caution with title "Finder Shrink"'
    else
        printf '%s\n' 'Finder Shrink: please set Automator shell to /bin/bash.'
    fi
    exit 0
fi

set +e
IFS=$'\n\t'

export PATH="/opt/homebrew/bin:/usr/local/bin:/opt/imagemagick/bin:/usr/bin:/bin:/usr/sbin:/sbin"

APP_NAME="Finder Shrink"
MARKER_V2="__FINDER_SHRINK_V2__"
MARKER_V1="__FINDER_SHRINK_V1__"
LOG_DIR="${HOME}/Library/Logs/FinderShrink"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/$(date '+%Y%m%d_%H%M%S').log"
touch "$LOG_FILE"

# Keep Automator stdout open for the final result line before redirecting logs.
exec 3>&1

# Write every command error and diagnostic to the log. Automator still receives
# the final "Log: ..." line, but no hidden stderr should remain.
exec >> "$LOG_FILE" 2>&1

SHOW_FINISH_DIALOG=0
WRITE_OUTPUT_IF_NOT_SMALLER=0

OUTPUT_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0
MEDIA_OK_COUNT=0
MEDIA_SKIP_COUNT=0
MEDIA_FAIL_COUNT=0

timestamp() {
    date '+%H:%M:%S'
}

log() {
    printf '[%s] %s\n' "$(timestamp)" "$*"
}

notify() {
    [ -x /usr/bin/osascript ] || return 0
    /usr/bin/osascript \
        -e 'on run argv' \
        -e 'display notification (item 1 of argv) with title "Finder Shrink"' \
        -e 'end run' \
        "$1" >/dev/null 2>&1 || true
}

dialog() {
    [ "$SHOW_FINISH_DIALOG" = "1" ] || return 0
    [ -x /usr/bin/osascript ] || return 0
    /usr/bin/osascript \
        -e 'on run argv' \
        -e 'display dialog (item 1 of argv) buttons {"OK"} default button "OK" with title "Finder Shrink"' \
        -e 'end run' \
        "$1" >/dev/null 2>&1 || true
}

normalize_preset() {
    case "$1" in
        preprocess) printf '%s\n' "prepress" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

valid_preset() {
    case "$1" in
        screen|ebook|printer|prepress) return 0 ;;
        *) return 1 ;;
    esac
}

get_ext() {
    local base ext
    base="$(basename "$1")"
    case "$base" in
        *.*)
            ext="${base##*.}"
            printf '%s\n' "$ext" | tr '[:upper:]' '[:lower:]'
            ;;
        *)
            printf '%s\n' ""
            ;;
    esac
}

is_image_ext() {
    case "$1" in
        jpg|jpeg|png|gif|tif|tiff|bmp|webp|heic|heif|avif|jp2|j2k) return 0 ;;
        *) return 1 ;;
    esac
}

is_video_ext() {
    case "$1" in
        mp4|m4v|mov|mkv|avi|webm|wmv|mpg|mpeg|3gp|3g2|flv|mts|m2ts|ts) return 0 ;;
        *) return 1 ;;
    esac
}

image_settings() {
    case "$1" in
        screen) printf '%s\n' "1024 60" ;;
        ebook) printf '%s\n' "1280 70" ;;
        printer) printf '%s\n' "1920 80" ;;
        prepress) printf '%s\n' "2560 90" ;;
        *) printf '%s\n' "1280 70" ;;
    esac
}

video_settings() {
    case "$1" in
        screen) printf '%s\n' "720 32 96k 40" ;;
        ebook) printf '%s\n' "1080 28 128k 36" ;;
        printer) printf '%s\n' "1440 23 160k 31" ;;
        prepress) printf '%s\n' "2160 18 192k 26" ;;
        *) printf '%s\n' "1080 28 128k 36" ;;
    esac
}

filesize() {
    stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || printf '%s\n' "0"
}

human_size() {
    awk -v bytes="$1" 'BEGIN {
        split("B KB MB GB TB", u, " ");
        s = bytes + 0;
        i = 1;
        while (s >= 1024 && i < 5) { s = s / 1024; i++ }
        if (i == 1) printf "%d%s", s, u[i];
        else printf "%.1f%s", s, u[i];
    }'
}

tmp_path() {
    local ext t
    ext="$1"
    t="$(mktemp "${TMPDIR:-/tmp}/finder_shrink.XXXXXX")"
    if [ -z "$t" ]; then
        return 1
    fi
    rm -f "$t"
    printf '%s.%s\n' "$t" "$ext"
}

make_output_path() {
    local src suffix override_ext dir base name ext candidate i
    src="$1"
    suffix="$2"
    override_ext="${3:-}"

    dir="$(dirname "$src")"
    base="$(basename "$src")"

    if [ -n "$override_ext" ]; then
        case "$base" in
            *.*) name="${base%.*}" ;;
            *) name="$base" ;;
        esac
        ext="$override_ext"
        candidate="${dir}/${name}_${suffix}.${ext}"
    else
        case "$base" in
            *.*)
                name="${base%.*}"
                ext="${base##*.}"
                candidate="${dir}/${name}_${suffix}.${ext}"
                ;;
            *)
                name="$base"
                ext=""
                candidate="${dir}/${name}_${suffix}"
                ;;
        esac
    fi

    if [ ! -e "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    i=2
    while :; do
        if [ -n "$override_ext" ]; then
            candidate="${dir}/${name}_${suffix}_${i}.${ext}"
        elif [ -n "$ext" ]; then
            candidate="${dir}/${name}_${suffix}_${i}.${ext}"
        else
            candidate="${dir}/${name}_${suffix}_${i}"
        fi

        if [ ! -e "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
        i=$((i + 1))
    done
}

accept_output() {
    local src dst tmp label src_size tmp_size
    src="$1"
    dst="$2"
    tmp="$3"
    label="$4"

    if [ ! -s "$tmp" ]; then
        log "FAIL: ${label}: $(basename "$src") -> output is empty."
        rm -f "$tmp"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 0
    fi

    src_size="$(filesize "$src")"
    tmp_size="$(filesize "$tmp")"

    if [ "$src_size" -eq 0 ] || [ "$tmp_size" -lt "$src_size" ] || [ "$WRITE_OUTPUT_IF_NOT_SMALLER" = "1" ]; then
        mv -f "$tmp" "$dst"
        OUTPUT_COUNT=$((OUTPUT_COUNT + 1))
        if [ "$tmp_size" -lt "$src_size" ]; then
            log "OK: ${label}: $(basename "$src") -> $(basename "$dst") ($(human_size "$src_size") -> $(human_size "$tmp_size"))"
        else
            log "WRITE: ${label}: $(basename "$src") -> $(basename "$dst") ($(human_size "$src_size") -> $(human_size "$tmp_size"); not smaller)"
        fi
        return 0
    fi

    rm -f "$tmp"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    log "SKIP: ${label}: $(basename "$src") would not become smaller ($(human_size "$src_size") -> $(human_size "$tmp_size")). No output file was written."
    return 0
}

finish_output() {
    local src dst tmp replace_mode label before_dst
    src="$1"
    dst="$2"
    tmp="$3"
    replace_mode="$4"
    label="$5"

    before_dst="$dst"
    accept_output "$src" "$dst" "$tmp" "$label"

    if [ -e "$before_dst" ] && [ "$replace_mode" = "replace" ]; then
        rm -f "$src"
    fi

    return 0
}

accept_smaller_in_place() {
    local src tmp label src_size tmp_size
    src="$1"
    tmp="$2"
    label="$3"

    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        MEDIA_FAIL_COUNT=$((MEDIA_FAIL_COUNT + 1))
        log "  media FAIL: $label -> output is empty"
        return 0
    fi

    src_size="$(filesize "$src")"
    tmp_size="$(filesize "$tmp")"

    if [ "$src_size" -eq 0 ] || [ "$tmp_size" -lt "$src_size" ]; then
        mv -f "$tmp" "$src"
        MEDIA_OK_COUNT=$((MEDIA_OK_COUNT + 1))
        log "  media OK: $label ($(human_size "$src_size") -> $(human_size "$tmp_size"))"
        return 0
    fi

    rm -f "$tmp"
    MEDIA_SKIP_COUNT=$((MEDIA_SKIP_COUNT + 1))
    log "  media SKIP: $label would not become smaller ($(human_size "$src_size") -> $(human_size "$tmp_size"))"
    return 0
}

compress_pdf() {
    local src preset mode dst tmp rc
    src="$1"
    preset="$2"
    mode="$3"

    if [ -z "$GS_CMD" ]; then
        log "SKIP: PDF: $(basename "$src") (gs not found)"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        return 0
    fi

    dst="$(make_output_path "$src" "$preset")"
    tmp="$(tmp_path "pdf")"
    if [ -z "$tmp" ]; then
        log "FAIL: PDF: could not create temp file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 0
    fi

    "$GS_CMD" \
        -sDEVICE=pdfwrite \
        -dCompatibilityLevel=1.4 \
        "-dPDFSETTINGS=/${preset}" \
        -dDetectDuplicateImages=true \
        -dCompressFonts=true \
        -dSubsetFonts=true \
        -dNOPAUSE \
        -dQUIET \
        -dBATCH \
        "-sOutputFile=$tmp" \
        "$src"
    rc="$?"

    if [ "$rc" -ne 0 ]; then
        rm -f "$tmp"
        log "FAIL: PDF: $(basename "$src") (gs exit $rc)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 0
    fi

    finish_output "$src" "$dst" "$tmp" "$mode" "PDF"
}

compress_image_to_file() {
    local preset src out settings max quality ext rc
    preset="$1"
    src="$2"
    out="$3"

    if [ -z "$IM_CMD" ]; then
        return 1
    fi

    settings="$(image_settings "$preset")"
    local old_ifs
    old_ifs="$IFS"
    IFS=' '
    set -- $settings
    IFS="$old_ifs"
    max="${1:-1280}"
    quality="${2:-70}"
    ext="$(get_ext "$src")"

    if [ "$ext" = "gif" ]; then
        "$IM_CMD" "$src" -coalesce -resize "${max}x${max}>" -layers Optimize "$out"
    else
        "$IM_CMD" "$src" -auto-orient -resize "${max}x${max}>" -strip -quality "$quality" "$out"
    fi
    rc="$?"
    return "$rc"
}

compress_image() {
    local src preset mode ext dst tmp
    src="$1"
    preset="$2"
    mode="$3"

    if [ -z "$IM_CMD" ]; then
        log "SKIP: Image: $(basename "$src") (ImageMagick not found)"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        return 0
    fi

    ext="$(get_ext "$src")"
    dst="$(make_output_path "$src" "$preset")"
    tmp="$(tmp_path "$ext")"
    if [ -z "$tmp" ]; then
        log "FAIL: Image: could not create temp file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 0
    fi

    if compress_image_to_file "$preset" "$src" "$tmp"; then
        finish_output "$src" "$dst" "$tmp" "$mode" "Image"
    else
        rm -f "$tmp"
        log "FAIL: Image: $(basename "$src")"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    return 0
}

compress_image_in_place() {
    local preset src ext tmp
    preset="$1"
    src="$2"

    if [ -z "$IM_CMD" ]; then
        MEDIA_FAIL_COUNT=$((MEDIA_FAIL_COUNT + 1))
        log "  media FAIL: $(basename "$src") (ImageMagick not found)"
        return 0
    fi

    ext="$(get_ext "$src")"
    tmp="$(tmp_path "$ext")"
    if [ -z "$tmp" ]; then
        MEDIA_FAIL_COUNT=$((MEDIA_FAIL_COUNT + 1))
        log "  media FAIL: $(basename "$src") (could not create temp file)"
        return 0
    fi

    if compress_image_to_file "$preset" "$src" "$tmp"; then
        accept_smaller_in_place "$src" "$tmp" "$(basename "$src")"
    else
        rm -f "$tmp"
        MEDIA_FAIL_COUNT=$((MEDIA_FAIL_COUNT + 1))
        log "  media FAIL: $(basename "$src") (ImageMagick conversion failed)"
    fi
    return 0
}

compress_video_to_file() {
    local preset src out settings max crf audio_bitrate vp9_crf out_ext vf rc
    preset="$1"
    src="$2"
    out="$3"

    if [ -z "$FFMPEG_CMD" ]; then
        return 1
    fi

    settings="$(video_settings "$preset")"
    local old_ifs
    old_ifs="$IFS"
    IFS=' '
    set -- $settings
    IFS="$old_ifs"
    max="${1:-1080}"
    crf="${2:-28}"
    audio_bitrate="${3:-128k}"
    vp9_crf="${4:-36}"

    out_ext="$(get_ext "$out")"
    vf="scale='if(gt(iw,ih),min(iw,${max}),-2)':'if(gt(iw,ih),-2,min(ih,${max}))'"

    if [ "$out_ext" = "webm" ]; then
        "$FFMPEG_CMD" -y -hide_banner -loglevel error \
            -i "$src" \
            -map 0:v:0 -map "0:a?" \
            -vf "$vf" \
            -c:v libvpx-vp9 -b:v 0 -crf "$vp9_crf" -row-mt 1 \
            -c:a libopus -b:a "$audio_bitrate" \
            "$out"
    else
        "$FFMPEG_CMD" -y -hide_banner -loglevel error \
            -i "$src" \
            -map 0:v:0 -map "0:a?" \
            -vf "$vf" \
            -c:v libx264 -preset medium -crf "$crf" -pix_fmt yuv420p \
            -c:a aac -b:a "$audio_bitrate" \
            "$out"
    fi
    rc="$?"
    return "$rc"
}

compress_video() {
    local src preset mode ext dst tmp
    src="$1"
    preset="$2"
    mode="$3"

    if [ -z "$FFMPEG_CMD" ]; then
        log "SKIP: Video: $(basename "$src") (ffmpeg not found)"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        return 0
    fi

    ext="$(get_ext "$src")"
    dst="$(make_output_path "$src" "$preset")"
    tmp="$(tmp_path "$ext")"
    if [ -z "$tmp" ]; then
        log "FAIL: Video: could not create temp file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 0
    fi

    if compress_video_to_file "$preset" "$src" "$tmp"; then
        finish_output "$src" "$dst" "$tmp" "$mode" "Video"
        return 0
    fi

    rm -f "$tmp"

    if [ "$ext" != "mp4" ]; then
        log "WARN: Video: $(basename "$src") failed with the same extension. Retrying as mp4."
        dst="$(make_output_path "$src" "$preset" "mp4")"
        tmp="$(tmp_path "mp4")"
        if [ -n "$tmp" ] && compress_video_to_file "$preset" "$src" "$tmp"; then
            finish_output "$src" "$dst" "$tmp" "$mode" "Video"
            return 0
        fi
        rm -f "$tmp"
    fi

    log "FAIL: Video: $(basename "$src")"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 0
}

compress_video_in_place() {
    local preset src ext tmp
    preset="$1"
    src="$2"

    if [ -z "$FFMPEG_CMD" ]; then
        MEDIA_FAIL_COUNT=$((MEDIA_FAIL_COUNT + 1))
        log "  media FAIL: $(basename "$src") (ffmpeg not found)"
        return 0
    fi

    ext="$(get_ext "$src")"
    tmp="$(tmp_path "$ext")"
    if [ -z "$tmp" ]; then
        MEDIA_FAIL_COUNT=$((MEDIA_FAIL_COUNT + 1))
        log "  media FAIL: $(basename "$src") (could not create temp file)"
        return 0
    fi

    if compress_video_to_file "$preset" "$src" "$tmp"; then
        accept_smaller_in_place "$src" "$tmp" "$(basename "$src")"
    else
        rm -f "$tmp"
        MEDIA_FAIL_COUNT=$((MEDIA_FAIL_COUNT + 1))
        log "  media FAIL: $(basename "$src") (ffmpeg conversion failed)"
    fi
    return 0
}

process_media_file() {
    local preset f e
    preset="$1"
    f="$2"

    [ -f "$f" ] || return 0
    e="$(get_ext "$f")"
    if is_image_ext "$e"; then
        compress_image_in_place "$preset" "$f"
    elif is_video_ext "$e"; then
        compress_video_in_place "$preset" "$f"
    fi
    return 0
}

compress_office() {
    local src preset mode ext dst tmpout work media_root list f rc media_before changed
    src="$1"
    preset="$2"
    mode="$3"

    if [ -z "$ZIP_CMD" ] || [ -z "$UNZIP_CMD" ]; then
        log "SKIP: Office: $(basename "$src") (zip/unzip not found)"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        return 0
    fi

    ext="$(get_ext "$src")"
    dst="$(make_output_path "$src" "$preset")"
    tmpout="$(tmp_path "$ext")"
    work="$(mktemp -d "${TMPDIR:-/tmp}/finder_shrink_office.XXXXXX")"

    if [ -z "$tmpout" ] || [ -z "$work" ]; then
        rm -rf "$work"
        rm -f "$tmpout"
        log "FAIL: Office: $(basename "$src") (could not create temp area)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 0
    fi

    log "Office: expanding $(basename "$src")"
    "$UNZIP_CMD" -q "$src" -d "$work"
    rc="$?"

    if [ "$rc" -ne 0 ]; then
        # Some archives extract with warnings. Continue only if the structure looks
        # like an Office document.
        if [ ! -f "$work/[Content_Types].xml" ]; then
            rm -rf "$work"
            rm -f "$tmpout"
            log "FAIL: Office: $(basename "$src") could not be expanded (unzip exit $rc)"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            return 0
        fi
        log "WARN: Office: unzip returned $rc, but Office structure was extracted; continuing."
    fi

    if [ "$ext" = "docx" ]; then
        media_root="$work/word/media"
    else
        media_root="$work/ppt/media"
    fi

    media_before="$MEDIA_OK_COUNT"
    if [ -d "$media_root" ]; then
        list="$(mktemp "${TMPDIR:-/tmp}/finder_shrink_media.XXXXXX")"
        if [ -n "$list" ]; then
            find "$media_root" -type f -print0 > "$list"
            while IFS= read -r -d '' f; do
                process_media_file "$preset" "$f"
            done < "$list"
            rm -f "$list"
        fi
    else
        log "Office: no media directory found in $(basename "$src")"
    fi

    changed=$((MEDIA_OK_COUNT - media_before))
    log "Office: media changed in $(basename "$src"): $changed"

    (cd "$work" && "$ZIP_CMD" -qr -X "$tmpout" .)
    rc="$?"

    rm -rf "$work"

    if [ "$rc" -ne 0 ]; then
        rm -f "$tmpout"
        log "FAIL: Office: $(basename "$src") could not be rebuilt (zip exit $rc)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 0
    fi

    finish_output "$src" "$dst" "$tmpout" "$mode" "Office"
    return 0
}

compress_zip() {
    local src preset mode dst tmpout work list f rc
    src="$1"
    preset="$2"
    mode="$3"

    if [ -z "$ZIP_CMD" ] || [ -z "$UNZIP_CMD" ]; then
        log "SKIP: ZIP: $(basename "$src") (zip/unzip not found)"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        return 0
    fi

    dst="$(make_output_path "$src" "$preset")"
    tmpout="$(tmp_path "zip")"
    work="$(mktemp -d "${TMPDIR:-/tmp}/finder_shrink_zip.XXXXXX")"

    if [ -z "$tmpout" ] || [ -z "$work" ]; then
        rm -rf "$work"
        rm -f "$tmpout"
        log "FAIL: ZIP: $(basename "$src") (could not create temp area)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 0
    fi

    log "ZIP: expanding $(basename "$src")"
    "$UNZIP_CMD" -q "$src" -d "$work"
    rc="$?"

    if [ "$rc" -ne 0 ]; then
        rm -rf "$work"
        rm -f "$tmpout"
        log "FAIL: ZIP: $(basename "$src") could not be expanded (unzip exit $rc)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 0
    fi

    list="$(mktemp "${TMPDIR:-/tmp}/finder_shrink_ziplist.XXXXXX")"
    if [ -n "$list" ]; then
        find "$work" -type f -print0 > "$list"
        while IFS= read -r -d '' f; do
            [ -f "$f" ] || continue
            process_file "$f" "replace"
        done < "$list"
        rm -f "$list"
    fi

    (cd "$work" && "$ZIP_CMD" -qr -X "$tmpout" .)
    rc="$?"

    rm -rf "$work"

    if [ "$rc" -ne 0 ]; then
        rm -f "$tmpout"
        log "FAIL: ZIP: $(basename "$src") could not be rebuilt (zip exit $rc)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 0
    fi

    finish_output "$src" "$dst" "$tmpout" "$mode" "ZIP"
    return 0
}

process_file() {
    local src mode ext
    src="$1"
    mode="$2"

    if [ ! -f "$src" ]; then
        log "SKIP: $(basename "$src") is not a regular file."
        SKIP_COUNT=$((SKIP_COUNT + 1))
        return 0
    fi

    ext="$(get_ext "$src")"
    log "Processing: $(basename "$src")"

    case "$ext" in
        pdf)
            compress_pdf "$src" "$PDF_PRESET" "$mode"
            ;;
        docx|pptx)
            compress_office "$src" "$OFFICE_PRESET" "$mode"
            ;;
        zip)
            compress_zip "$src" "$ZIP_PRESET" "$mode"
            ;;
        *)
            if is_image_ext "$ext"; then
                compress_image "$src" "$IMAGE_PRESET" "$mode"
            elif is_video_ext "$ext"; then
                compress_video "$src" "$VIDEO_PRESET" "$mode"
            else
                log "SKIP: $(basename "$src") is not a supported extension."
                SKIP_COUNT=$((SKIP_COUNT + 1))
            fi
            ;;
    esac

    return 0
}

parse_input() {
    if [ "$#" -lt 7 ]; then
        log "ERROR: No usable arguments were received."
        log "Automator settings must be: Shell=/bin/bash, Pass input=as arguments."
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi

    if [ "$1" != "$MARKER_V2" ] && [ "$1" != "$MARKER_V1" ]; then
        log "ERROR: Unexpected Automator input marker: $1"
        log "Make sure the AppleScript action is above this shell action."
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
    shift

    PDF_PRESET="$(normalize_preset "${1#PDF=}")"; shift
    OFFICE_PRESET="$(normalize_preset "${1#OFFICE=}")"; shift
    IMAGE_PRESET="$(normalize_preset "${1#IMAGE=}")"; shift
    VIDEO_PRESET="$(normalize_preset "${1#VIDEO=}")"; shift
    ZIP_PRESET="$(normalize_preset "${1#ZIP=}")"; shift

    for p in "$PDF_PRESET" "$OFFICE_PRESET" "$IMAGE_PRESET" "$VIDEO_PRESET" "$ZIP_PRESET"; do
        if ! valid_preset "$p"; then
            log "ERROR: Invalid preset: $p"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            return 1
        fi
    done

    FILE_ARGS=("$@")
    return 0
}

main() {
    log "=== Finder Shrink start ==="
    log "Log: $LOG_FILE"

    parse_input "$@"
    if [ "$?" -ne 0 ]; then
        dialog "入力形式が不正です。Automator設定を確認してください。\n\nシェル: /bin/bash\n入力の引き渡し: 引数として\n\nログ:\n$LOG_FILE"
        printf 'Log: %s\n' "$LOG_FILE" >&3 2>/dev/null
        return 0
    fi

    log "PDF=$PDF_PRESET OFFICE=$OFFICE_PRESET IMAGE=$IMAGE_PRESET VIDEO=$VIDEO_PRESET ZIP=$ZIP_PRESET"
    log "Commands: gs=${GS_CMD:-not found}; ImageMagick=${IM_CMD:-not found}; ffmpeg=${FFMPEG_CMD:-not found}; zip=${ZIP_CMD:-not found}; unzip=${UNZIP_CMD:-not found}"

    for item in "${FILE_ARGS[@]}"; do
        process_file "$item" "keep"
    done

    log "Summary: output=$OUTPUT_COUNT skip=$SKIP_COUNT fail=$FAIL_COUNT media_ok=$MEDIA_OK_COUNT media_skip=$MEDIA_SKIP_COUNT media_fail=$MEDIA_FAIL_COUNT"
    log "=== Finder Shrink done ==="

    if [ "$FAIL_COUNT" -gt 0 ]; then
        dialog "Finder Shrink は完了しましたが、失敗があります。\n\n出力: $OUTPUT_COUNT\nスキップ: $SKIP_COUNT\n失敗: $FAIL_COUNT\n内部メディア圧縮: $MEDIA_OK_COUNT\n\nログ:\n$LOG_FILE"
    elif [ "$OUTPUT_COUNT" -eq 0 ]; then
        dialog "Finder Shrink は完了しましたが、新しいファイルは作成されませんでした。\n\n主な理由は、圧縮後のファイルが元より小さくならなかった、または対象メディアが無かったためです。\n\nログ:\n$LOG_FILE"
    else
        notify "完了: 出力 $OUTPUT_COUNT 件 / スキップ $SKIP_COUNT 件"
        if [ "$SHOW_FINISH_DIALOG" = "1" ]; then
            dialog "Finder Shrink 完了\n\n出力: $OUTPUT_COUNT\nスキップ: $SKIP_COUNT\n失敗: $FAIL_COUNT\n内部メディア圧縮: $MEDIA_OK_COUNT\n\nログ:\n$LOG_FILE"
        fi
    fi

    return 0
}

# Commands are resolved after PATH is set and before main starts.
GS_CMD="$(command -v gs 2>/dev/null || true)"
IM_CMD="$(command -v magick 2>/dev/null || command -v convert 2>/dev/null || true)"
FFMPEG_CMD="$(command -v ffmpeg 2>/dev/null || true)"
ZIP_CMD="$(command -v zip 2>/dev/null || true)"
UNZIP_CMD="$(command -v unzip 2>/dev/null || true)"

main "$@"

# Automator should not show a blank error dialog. Check the log for actual
# failures and skips.
printf 'Log: %s\n' "$LOG_FILE" >&3
exit 0

