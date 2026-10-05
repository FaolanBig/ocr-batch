#!/usr/bin/env bash

set -Eeuo pipefail

#####################
### Configuration ###
#####################

SCRIPT_NAME="$(basename "$0")"

SOURCE_DIR="${1:-}"
TARGET_DIR="${2:-}"

#################
### Functions ###
#################

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

update_status() {
    local now elapsed remaining eta percent

    now=$(date +%s)
    elapsed=$((now - START_TIME))

    remaining=$((TOTAL_FILES - PROCESSED_FILES))

    if (( PROCESSED_FILES > 0 )); then
        eta=$((elapsed * remaining / PROCESSED_FILES))
    else
        eta=0
    fi

    if (( TOTAL_FILES > 0 )); then
        percent=$((PROCESSED_FILES * 100 / TOTAL_FILES))
    else
        percent=100
    fi

    cat > "$STATUS_FILE" <<EOF
Progress:         ${percent}%

Total files:      $TOTAL_FILES
Processed files:  $PROCESSED_FILES
Remaining files:  $remaining

PDFs total:       $TOTAL_PDFS
PDFs processed:   $PROCESSED_PDFS
PDFs remaining:   $((TOTAL_PDFS - PROCESSED_PDFS))
PDFs failed:      ${FAILED_PDFS:-0}

Elapsed:          ${elapsed}s
ETA:              ${eta}s

Current file:     ${CURRENT_FILE:-}
EOF
}

cleanup() {
    rm -f "$STATUS_FILE"
}

handle_signal() {
    local signal_name="$1"
    local exit_code="$2"

    echo "[INTERRUPTED] Received SIG${signal_name} while processing: ${CURRENT_FILE:-unknown}" \
        | tee -a "$ERROR_LOG" >&2
    exit "$exit_code"
}

trap cleanup EXIT

##################
### Validation ###
##################

if [[ -z "$SOURCE_DIR" || -z "$TARGET_DIR" ]]; then
    die "Usage: $SCRIPT_NAME <source_dir> <target_dir>"
fi

command -v ocrmypdf >/dev/null \
    || die "ocrmypdf not found"

command -v tmux >/dev/null \
    || die "tmux not found"

command -v realpath >/dev/null \
    || die "realpath not found"

SOURCE_DIR="$(realpath "$SOURCE_DIR")"
TARGET_DIR="$(realpath -m "$TARGET_DIR")"
CPU_THREADS="${OCR_JOBS:-2}"

[[ "$CPU_THREADS" =~ ^[1-9][0-9]*$ ]] \
    || die "OCR_JOBS must be a positive integer."

[[ -d "$SOURCE_DIR" ]] \
    || die "Source directory does not exist."

if [[ "$SOURCE_DIR" == "$TARGET_DIR" ]]; then
    die "Source and target directory must be different."
fi

if [[ "$TARGET_DIR" == "$SOURCE_DIR/"* ]]; then
    die "Target directory must not be located inside source directory."
fi

mkdir -p "$TARGET_DIR"

#####################
### tmux handling ###
#####################

if [[ -z "${TMUX:-}" ]]; then
    die "This script must be started from inside a tmux session."
fi

RUN_ID="$(date +%Y%m%d_%H%M%S)"

STATUS_FILE="/tmp/ocr_status_${RUN_ID}"
OCR_LOG="/tmp/ocr_output_${RUN_ID}.log"
ERROR_LOG="/tmp/ocr_errors_${RUN_ID}.log"

touch "$STATUS_FILE" "$OCR_LOG" "$ERROR_LOG"
trap 'handle_signal INT 130' INT
trap 'handle_signal TERM 143' TERM
trap 'handle_signal HUP 129' HUP

CURRENT_PANE="$(tmux display-message -p "#{pane_id}")"

####################
### Create panes ###
####################

PROGRESS_PANE=$(
    tmux split-window \
        -v \
        -l 20 \
        -P \
        -F "#{pane_id}"
)

tmux select-pane -t "$CURRENT_PANE"

LOG_PANE=$(
    tmux split-window \
        -h \
        -l 120 \
        -P \
        -F "#{pane_id}"
)

#####################
### Progress pane ###
#####################

tmux send-keys -t "$PROGRESS_PANE" "
while true; do
    clear
    echo '==== OCR Progress ===='
    echo
    cat '$STATUS_FILE' 2>/dev/null || true
    sleep 1
done
" C-m

################
### Log pane ###
################

tmux send-keys -t "$LOG_PANE" "
tail -n 50 -F '$OCR_LOG'
" C-m

#######################
### Build file list ###
#######################

echo "[INFO] Scanning source directory ..."

mapfile -d '' ALL_FILES < <(
    find "$SOURCE_DIR" -type f -print0
)

mapfile -d '' PDF_FILES < <(
    find "$SOURCE_DIR" -type f -iname '*.pdf' -print0
)

TOTAL_FILES=${#ALL_FILES[@]}
TOTAL_PDFS=${#PDF_FILES[@]}

PROCESSED_FILES=0
PROCESSED_PDFS=0
FAILED_PDFS=0

START_TIME=$(date +%s)

update_status

##########################
### Copy non-PDF files ###
##########################

echo "[INFO] Copying non-PDF files ..."

for file in "${ALL_FILES[@]}"; do

    rel="${file#$SOURCE_DIR/}"
    out="$TARGET_DIR/$rel"

    mkdir -p "$(dirname "$out")"

    CURRENT_FILE="$rel"

    if [[ "$file" =~ \.[Pp][Dd][Ff]$ ]]; then
        continue
    fi

    if [[ -f "$out" ]]; then
        echo "[SKIP] $rel"
        ((PROCESSED_FILES+=1))
        update_status
        continue
    fi

    if cp -a -- "$file" "$out"; then
        :
    else
        echo "[ERROR] Failed to copy: $file" >> "$ERROR_LOG"
    fi

    ((PROCESSED_FILES+=1))
    update_status
done

################
### OCR PDFs ###
################

echo "[INFO] Starting OCR processing ..."

for pdf in "${PDF_FILES[@]}"; do

    rel="${pdf#$SOURCE_DIR/}"
    out="$TARGET_DIR/$rel"
    tmp_out="${out}.ocr-${RUN_ID}.tmp.pdf"

    mkdir -p "$(dirname "$out")"

    CURRENT_FILE="$rel"

    if [[ -f "$out" ]]; then
        echo "[SKIP] $rel"

        ((PROCESSED_FILES+=1))
        ((PROCESSED_PDFS+=1))

        update_status
        continue
    fi

    {
        echo
        echo "================================================="
        echo "START: $(date)"
        echo "FILE : $rel"
        echo "================================================="
        echo
    } >> "$OCR_LOG"

    if ocrmypdf \
        --rotate-pages \
        --deskew \
        --clean \
        --clean-final \
        --optimize 3 \
	--output-type pdf \
        --skip-text \
	--jobs "$CPU_THREADS" \
        "$pdf" \
        "$tmp_out" >> "$OCR_LOG" 2>&1
    then
        if mv -f -- "$tmp_out" "$out"; then
            echo "[SUCCESS] completed OCR for $pdf"
        else
            rc=$?
            echo "[ERROR] Failed to publish OCR output: $pdf (exit code=$rc)" \
                | tee -a "$ERROR_LOG"
            rm -f -- "$tmp_out"
            ((FAILED_PDFS+=1))
        fi
    else
        rc=$?

        echo "[ERROR] OCR failed: $pdf (exit code=$rc)" \
            | tee -a "$ERROR_LOG"
        rm -f -- "$tmp_out"
        ((FAILED_PDFS+=1))

    fi

    ((PROCESSED_FILES+=1))
    ((PROCESSED_PDFS+=1))

    update_status

done

################
### Finished ###
################

END_TIME=$(date +%s)

if (( FAILED_PDFS > 0 )); then
    JOB_RESULT="Job completed with errors."
else
    JOB_RESULT="Job completed successfully."
fi

cat > "$STATUS_FILE" <<EOF
$JOB_RESULT

Total files:      $TOTAL_FILES
Processed files:  $PROCESSED_FILES

PDFs total:       $TOTAL_PDFS
PDFs processed:   $PROCESSED_PDFS
PDFs failed:      $FAILED_PDFS
PDFs failed:      $FAILED_PDFS

Runtime:          $((END_TIME - START_TIME))s

OCR Log:          $OCR_LOG
Error Log:        $ERROR_LOG
EOF

echo
echo "[INFO] Finished."
echo "[INFO] Runtime: $((END_TIME - START_TIME))s"
echo "[INFO] OCR log  : $OCR_LOG"
echo "[INFO] Error log: $ERROR_LOG"

if (( FAILED_PDFS > 0 )); then
    echo "[ERROR] Finished with $FAILED_PDFS failed PDF(s). Rerun to retry them."
    exit 1
fi
