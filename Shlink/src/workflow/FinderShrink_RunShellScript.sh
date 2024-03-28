#!/bin/bash
set -u
IFS='
	'

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

APP_NAME="Finder Shrink"
MARKER="__FINDER_SHRINK_V1__"
LOG_DIR="${HOME}/Library/Logs/FinderShrink"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/$(date '+%Y%m%d_%H%M%S').log"
touch "$LOG_FILE"

log() {
    printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

notify() {
    /usr/bin/osascript \
        -e 'on run argv' \
        -e 'display notification (item 1 of argv) with title "Finder Shrink"' \
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

if [ "$#" -lt 7 ]; then
    exit 0
fi

if [ "$1" != "$MARKER" ]; then
    log "ERROR: Unexpected Automator input."
    notify "入力形式が不正です。AutomatorのAppleScriptアクションを確認してください。"
    exit 1
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
        notify "圧縮プリセットが不正です: $p"
        exit 1
    fi
done

GS_CMD="$(command -v gs 2>/dev/null || true)"
IM_CMD="$(command -v magick 2>/dev/null || command -v convert 2>/dev/null || true)"
FFMPEG_CMD="$(command -v ffmpeg 2>/dev/null || true)"
ZIP_CMD="$(command -v zip 2>/dev/null || true)"
UNZIP_CMD="$(command -v unzip 2>/dev/null || true)"

[ -z "$GS_CMD" ] && log "WARN: gs が見つかりません。PDFはスキップされます。"
[ -z "$IM_CMD" ] && log "WARN: ImageMagick(magick/convert) が見つかりません。画像とOffice内画像はスキップされます。"
[ -z "$FFMPEG_CMD" ] && log "WARN: ffmpeg が見つかりません。動画はスキップされます。"
[ -z "$ZIP_CMD" ] && log "WARN: zip が見つかりません。docx/pptx/zipの再作成はスキップされます。"
[ -z "$UNZIP_CMD" ] && log "WARN: unzip が見つかりません。docx/pptx/zipの展開はスキップされます。"

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
    esac
}

video_settings() {
    case "$1" in
        screen) printf '%s\n' "720 32 96k 40" ;;
        ebook) printf '%s\n' "1080 28 128k 36" ;;
        printer) printf '%s\n' "1440 23 160k 31" ;;
        prepress) printf '%s\n' "2160 18 192k 26" ;;
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
    t="$(mktemp "${TMPDIR:-/tmp}/finder_shrink.XXXXXX")" || return 1
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

accept_smaller() {
    local src dst tmp src_size tmp_size
    src="$1"
    dst="$2"
    tmp="$3"

    if [ ! -s "$tmp" ]; then
        log "FAIL: $(basename "$src") -> 出力が空です。"
        rm -f "$tmp"
        return 1
    fi

    src_size="$(filesize "$src")"
    tmp_size="$(filesize "$tmp")"

    if [ "$src_size" -eq 0 ] || [ "$tmp_size" -lt "$src_size" ]; then
        mv -f "$tmp" "$dst"
        log "OK: $(basename "$src") -> $(basename "$dst") ($(human_size "$src_size") -> $(human_size "$tmp_size"))"
        return 0
    fi

    rm -f "$tmp"
    log "SKIP: $(basename "$src") は圧縮後の方が大きいため出力しません ($(human_size "$src_size") -> $(human_size "$tmp_size"))"
    return 2
}

finish_output() {
    local src dst tmp replace_mode rc
    src="$1"
    dst="$2"
    tmp="$3"
    replace_mode="$4"

    accept_smaller "$src" "$dst" "$tmp"
    rc="$?"

    if [ "$rc" -eq 0 ] && [ "$replace_mode" = "replace" ]; then
        rm -f "$src"
    fi

    return "$rc"
}

accept_smaller_in_place() {
    local src tmp label src_size tmp_size
    src="$1"
    tmp="$2"
    label="$3"

    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        return 1
    fi

    src_size="$(filesize "$src")"
    tmp_size="$(filesize "$tmp")"

    if [ "$src_size" -eq 0 ] || [ "$tmp_size" -lt "$src_size" ]; then
        mv -f "$tmp" "$src"
        log "  media OK: $label ($(human_size "$src_size") -> $(human_size "$tmp_size"))"
        return 0
    fi

    rm -f "$tmp"
    return 2
}

compress_pdf() {
    local src preset mode dst tmp rc
    src="$1"
    preset="$2"
    mode="$3"

    if [ -z "$GS_CMD" ]; then
        log "SKIP: PDF $(basename "$src") (gs がありません)"
        return 1
    fi

    dst="$(make_output_path "$src" "$preset")"
    tmp="$(tmp_path "pdf")" || return 1

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
        log "FAIL: PDF $(basename "$src") (gs exit $rc)"
        return 1
    fi

    finish_output "$src" "$dst" "$tmp" "$mode"
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
    set -- $settings
    max="$1"
    quality="$2"
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
        log "SKIP: Image $(basename "$src") (ImageMagick がありません)"
        return 1
    fi

    ext="$(get_ext "$src")"
    dst="$(make_output_path "$src" "$preset")"
    tmp="$(tmp_path "$ext")" || return 1

    if compress_image_to_file "$preset" "$src" "$tmp"; then
        finish_output "$src" "$dst" "$tmp" "$mode"
    else
        rm -f "$tmp"
        log "FAIL: Image $(basename "$src")"
        return 1
    fi
}

compress_image_in_place() {
    local preset src ext tmp
    preset="$1"
    src="$2"

    [ -z "$IM_CMD" ] && return 1

    ext="$(get_ext "$src")"
    tmp="$(tmp_path "$ext")" || return 1

    if compress_image_to_file "$preset" "$src" "$tmp"; then
        accept_smaller_in_place "$src" "$tmp" "$(basename "$src")"
    else
        rm -f "$tmp"
        return 1
    fi
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
    set -- $settings
    max="$1"
    crf="$2"
    audio_bitrate="$3"
    vp9_crf="$4"

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
        log "SKIP: Video $(basename "$src") (ffmpeg がありません)"
        return 1
    fi

    ext="$(get_ext "$src")"
    dst="$(make_output_path "$src" "$preset")"
    tmp="$(tmp_path "$ext")" || return 1

    if compress_video_to_file "$preset" "$src" "$tmp"; then
        finish_output "$src" "$dst" "$tmp" "$mode"
        return "$?"
    fi

    rm -f "$tmp"

    if [ "$ext" != "mp4" ]; then
        log "WARN: $(basename "$src") は同じ拡張子での動画圧縮に失敗しました。mp4で再試行します。"
        dst="$(make_output_path "$src" "$preset" "mp4")"
        tmp="$(tmp_path "mp4")" || return 1

        if compress_video_to_file "$preset" "$src" "$tmp"; then
            finish_output "$src" "$dst" "$tmp" "$mode"
            return "$?"
        fi
        rm -f "$tmp"
    fi

    log "FAIL: Video $(basename "$src")"
    return 1
}

compress_video_in_place() {
    local preset src ext tmp
    preset="$1"
    src="$2"

    [ -z "$FFMPEG_CMD" ] && return 1

    ext="$(get_ext "$src")"
    tmp="$(tmp_path "$ext")" || return 1

    if compress_video_to_file "$preset" "$src" "$tmp"; then
        accept_smaller_in_place "$src" "$tmp" "$(basename "$src")"
    else
        rm -f "$tmp"
        return 1
    fi
}

compress_office() {
    local src preset mode ext dst tmpout work media_root list f e rc
    src="$1"
    preset="$2"
    mode="$3"

    if [ -z "$ZIP_CMD" ] || [ -z "$UNZIP_CMD" ]; then
        log "SKIP: Office $(basename "$src") (zip/unzip がありません)"
        return 1
    fi

    ext="$(get_ext "$src")"
    dst="$(make_output_path "$src" "$preset")"
    tmpout="$(tmp_path "$ext")" || return 1
    work="$(mktemp -d "${TMPDIR:-/tmp}/finder_shrink_office.XXXXXX")" || return 1

    if ! "$UNZIP_CMD" -q "$src" -d "$work"; then
        rm -rf "$work"
        rm -f "$tmpout"
        log "FAIL: Office $(basename "$src") を展開できません"
        return 1
    fi

    if [ "$ext" = "docx" ]; then
        media_root="$work/word/media"
    else
        media_root="$work/ppt/media"
    fi

    if [ -d "$media_root" ]; then
        list="$(mktemp "${TMPDIR:-/tmp}/finder_shrink_media.XXXXXX")" || list=""
        if [ -n "$list" ]; then
            find "$media_root" -type f -print0 > "$list"
            while IFS= read -r -d '' f; do
                e="$(get_ext "$f")"
                if is_image_ext "$e"; then
                    compress_image_in_place "$preset" "$f" >/dev/null 2>&1 || true
                elif is_video_ext "$e"; then
                    compress_video_in_place "$preset" "$f" >/dev/null 2>&1 || true
                fi
            done < "$list"
            rm -f "$list"
        fi
    fi

    (cd "$work" && "$ZIP_CMD" -qr -X "$tmpout" .)
    rc="$?"

    rm -rf "$work"

    if [ "$rc" -ne 0 ]; then
        rm -f "$tmpout"
        log "FAIL: Office $(basename "$src") を再作成できません"
        return 1
    fi

    finish_output "$src" "$dst" "$tmpout" "$mode"
}

compress_zip() {
    local src preset mode dst tmpout work list f rc
    src="$1"
    preset="$2"
    mode="$3"

    if [ -z "$ZIP_CMD" ] || [ -z "$UNZIP_CMD" ]; then
        log "SKIP: ZIP $(basename "$src") (zip/unzip がありません)"
        return 1
    fi

    dst="$(make_output_path "$src" "$preset")"
    tmpout="$(tmp_path "zip")" || return 1
    work="$(mktemp -d "${TMPDIR:-/tmp}/finder_shrink_zip.XXXXXX")" || return 1

    if ! "$UNZIP_CMD" -q "$src" -d "$work"; then
        rm -rf "$work"
        rm -f "$tmpout"
        log "FAIL: ZIP $(basename "$src") を展開できません"
        return 1
    fi

    list="$(mktemp "${TMPDIR:-/tmp}/finder_shrink_ziplist.XXXXXX")" || list=""
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
        log "FAIL: ZIP $(basename "$src") を再作成できません"
        return 1
    fi

    finish_output "$src" "$dst" "$tmpout" "$mode"
}

process_file() {
    local src mode ext
    src="$1"
    mode="$2"

    if [ ! -f "$src" ]; then
        log "SKIP: $(basename "$src") は通常ファイルではありません"
        return 0
    fi

    ext="$(get_ext "$src")"

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
                log "SKIP: $(basename "$src") は対象外の拡張子です"
            fi
            ;;
    esac
}

log "=== Finder Shrink start ==="
log "PDF=$PDF_PRESET OFFICE=$OFFICE_PRESET IMAGE=$IMAGE_PRESET VIDEO=$VIDEO_PRESET ZIP=$ZIP_PRESET"
log "Log: $LOG_FILE"

for item in "$@"; do
    process_file "$item" "keep"
done

log "=== Finder Shrink done ==="
notify "処理が完了しました。ログ: $LOG_FILE"
printf 'Log: %s\n' "$LOG_FILE"
