#!/bin/sh
set -eu

# VIDLOOP mixed media player for Raspberry Pi OS Lite/Buster.
# Plays videos with omxplayer and images with fbi directly on the framebuffer.

CONFIG_FILE="${VIDLOOP_CONFIG_FILE:-/etc/default/vidloop}"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi

VIDLOOP_MEDIA_DIR="${VIDLOOP_MEDIA_DIR:-/home/vidloop/VIDLOOP44}"
VIDLOOP_IMAGE_DURATION_SEC="${VIDLOOP_IMAGE_DURATION_SEC:-20}"
VIDLOOP_WAIT_SEC="${VIDLOOP_WAIT_SEC:-0}"
VIDLOOP_TTY="${VIDLOOP_TTY:-1}"
VIDLOOP_FB_DEVICE="${VIDLOOP_FB_DEVICE:-/dev/fb0}"
VIDLOOP_VIDEO_ASPECT_MODE="${VIDLOOP_VIDEO_ASPECT_MODE:-fill}"
VIDLOOP_LOG_FILE="${VIDLOOP_LOG_FILE:-/var/log/vidloop44.log}"
VIDLOOP_SINGLE_VIDEO_LOOP="${VIDLOOP_SINGLE_VIDEO_LOOP:-true}"
VIDLOOP_EMPTY_SLEEP_SEC="${VIDLOOP_EMPTY_SLEEP_SEC:-5}"

STOP_REQUESTED=0
CURRENT_PID=""

log() {
    ts="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
    line="[$ts] $*"
    printf '%s\n' "$line"
    if [ -n "$VIDLOOP_LOG_FILE" ]; then
        printf '%s\n' "$line" >> "$VIDLOOP_LOG_FILE" 2>/dev/null || true
    fi
}

is_true() {
    case "${1:-}" in
        1|true|TRUE|yes|YES|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

is_image() {
    case "$1" in
        *.[Jj][Pp][Gg]|*.[Jj][Pp][Ee][Gg]|*.[Pp][Nn][Gg]|*.[Gg][Ii][Ff]|*.[Bb][Mm][Pp]) return 0 ;;
        *) return 1 ;;
    esac
}

is_video() {
    case "$1" in
        *.[Mm][Pp]4|*.[Mm]4[Vv]|*.[Mm][Oo][Vv]|*.[Mm][Kk][Vv]|*.[Aa][Vv][Ii]|*.[Mm][Pp][Gg]|*.[Mm][Pp][Ee][Gg]|*.[Tt][Ss]|*.[Mm]2[Tt][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

media_count() {
    find "$VIDLOOP_MEDIA_DIR" -maxdepth 1 -type f \( \
        -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.mpg' -o -iname '*.mpeg' -o -iname '*.ts' -o -iname '*.m2ts' -o \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' \
    \) 2>/dev/null | wc -l | tr -d ' '
}

first_media_file() {
    find "$VIDLOOP_MEDIA_DIR" -maxdepth 1 -type f \( \
        -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.mpg' -o -iname '*.mpeg' -o -iname '*.ts' -o -iname '*.m2ts' -o \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' \
    \) 2>/dev/null | sort | sed -n '1p'
}

list_media_files() {
    find "$VIDLOOP_MEDIA_DIR" -maxdepth 1 -type f \( \
        -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.mpg' -o -iname '*.mpeg' -o -iname '*.ts' -o -iname '*.m2ts' -o \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' \
    \) 2>/dev/null | sort
}

sleep_interruptible() {
    remaining="$1"
    while [ "$remaining" -gt 0 ]; do
        [ "$STOP_REQUESTED" -eq 0 ] || return 1
        sleep 1
        remaining=$((remaining - 1))
    done
    return 0
}

blank_tty() {
    if [ -w "/dev/tty$VIDLOOP_TTY" ]; then
        printf '\033c' > "/dev/tty$VIDLOOP_TTY" 2>/dev/null || true
    fi
}

stop_players() {
    if [ -n "$CURRENT_PID" ]; then
        kill "$CURRENT_PID" 2>/dev/null || true
        wait "$CURRENT_PID" 2>/dev/null || true
        CURRENT_PID=""
    fi
    pkill -TERM -x omxplayer.bin 2>/dev/null || true
    pkill -TERM -x fbi 2>/dev/null || true
    sleep 1
    pkill -KILL -x omxplayer.bin 2>/dev/null || true
    pkill -KILL -x fbi 2>/dev/null || true
    blank_tty
}

handle_stop() {
    STOP_REQUESTED=1
    stop_players
}

play_image() {
    file="$1"
    if ! command -v fbi >/dev/null 2>&1; then
        log "WARN fbi no esta instalado; no se puede mostrar imagen: $file"
        sleep_interruptible "$VIDLOOP_IMAGE_DURATION_SEC" || true
        return 0
    fi

    log "IMAGE $file"
    stop_players
    fbi -T "$VIDLOOP_TTY" -d "$VIDLOOP_FB_DEVICE" -noverbose -a "$file" >/dev/null 2>&1 &
    CURRENT_PID="$!"
    sleep_interruptible "$VIDLOOP_IMAGE_DURATION_SEC" || true
    stop_players
}

play_video() {
    file="$1"
    extra_loop="${2:-false}"

    if ! command -v omxplayer >/dev/null 2>&1; then
        log "WARN omxplayer no esta instalado; no se puede reproducir video: $file"
        sleep_interruptible 2 || true
        return 0
    fi

    log "VIDEO $file"
    stop_players

    if is_true "$extra_loop"; then
        omxplayer --no-osd --blank --aspect-mode "$VIDLOOP_VIDEO_ASPECT_MODE" --loop "$file" >/dev/null 2>&1 &
    else
        omxplayer --no-osd --blank --aspect-mode "$VIDLOOP_VIDEO_ASPECT_MODE" "$file" >/dev/null 2>&1 &
    fi
    CURRENT_PID="$!"
    wait "$CURRENT_PID" 2>/dev/null || true
    CURRENT_PID=""
    blank_tty
}

trap handle_stop INT TERM HUP
trap stop_players EXIT

mkdir -p "$VIDLOOP_MEDIA_DIR"
touch "$VIDLOOP_LOG_FILE" 2>/dev/null || true

log "VIDLOOP iniciado. Media dir: $VIDLOOP_MEDIA_DIR"

while [ "$STOP_REQUESTED" -eq 0 ]; do
    count="$(media_count)"

    if [ "$count" -eq 0 ]; then
        log "Sin medios compatibles. Esperando archivos en $VIDLOOP_MEDIA_DIR"
        sleep_interruptible "$VIDLOOP_EMPTY_SLEEP_SEC" || true
        continue
    fi

    if [ "$count" -eq 1 ] && is_true "$VIDLOOP_SINGLE_VIDEO_LOOP"; then
        only_file="$(first_media_file)"
        if [ -n "$only_file" ] && is_video "$only_file"; then
            play_video "$only_file" true
            continue
        fi
    fi

    list_media_files | while IFS= read -r media_file; do
        [ "$STOP_REQUESTED" -eq 0 ] || break
        [ -f "$media_file" ] || continue

        if is_image "$media_file"; then
            play_image "$media_file"
        elif is_video "$media_file"; then
            play_video "$media_file" false
        fi

        if [ "$VIDLOOP_WAIT_SEC" -gt 0 ]; then
            sleep_interruptible "$VIDLOOP_WAIT_SEC" || true
        fi
    done
done

exit 0
