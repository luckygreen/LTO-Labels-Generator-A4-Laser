#!/usr/bin/env bash
# Filename: LTO-Labels-Generator-A4-Laser-Printer-Only.sh
# Version: 27
# Date: 2026-05-11T22:00:00Z
# Author: Lucky Green in collaboration with ChatGPT and Claude
# Purpose:
#   Generate up to 30 LTO tape labels per A4 PDF page for printing on
#   laser-printer-only blank labels, such as Avery 4775 / L4775.
#
#   The generated labels are 79 mm x 17 mm, arranged two per row and
#   fifteen rows per page. Both color and B/W label variants are
#   supported. Color is the default; B/W is selected by passing -bw
#   or --bw. Cut guide lines extend to the paper edges.
#
#   Supported LTO generations: L1 through L9. Generation L0 is not valid.
#   For LTO generations beyond L9, pull requests are welcome.
#
#   LTO media is rated for long archival lifetimes, commonly up to 50 years.
#   The LTO label must remain readable for the useful life of the tape.
#   This logically precludes inkjet-printed or paper-based labels. Avery
#   4775 labels are polyester labels intended for laser printers and, per
#   the product box, are water, UV, and temperature resistant (-20C to +80C).
#
# Barcode encoding — MANDATORY flag, choose one:
#
#   -6 / --6  Six-character barcode: encodes only the VOLSER (e.g., BKUP01).
#             Use this when your library is configured for 6-character barcode
#             mode. The generation suffix (L8, L7, etc.) appears in the visual
#             label cells but is NOT encoded in the barcode.
#
#   -8 / --8  Eight-character barcode: encodes VOLSER + generation suffix
#             (e.g., BKUP01L8). Use this when your library is configured for
#             8-character barcode mode. This matches the IBMT LTO barcode
#             standard and is the format most modern libraries default to.
#
#   WARNING: All tapes in a single library must use the same barcode encoding.
#   Mixing 6-char and 8-char barcodes in the same library causes the library
#   to fail to inventory or load the mismatched tapes. Check your library's
#   barcode mode before printing labels.
#
# Barcode rendering (v27 fix):
#   Barcodes are generated at a fixed bar width of 0.30 mm, meeting the IBMT
#   LTO minimum of 0.254 mm (10 mil). The barcode is centered on the label;
#   the white space on each side provides the required quiet zone. Prior to
#   v27 the barcode was scaled to fill the full label width, which compressed
#   8-character barcodes below the scanner threshold while 6-character
#   barcodes were stretched wide enough to remain readable by accident.
#
# Repository:
#   https://github.com/luckygreen/LTO-Labels-Generator-A4-Laser
#   If you find this script useful, please consider starring the repository.
#
# Supported OS:
#   Debian / Ubuntu family systems with bash, apt, sudo, and internet access.
#   Tested target: Ubuntu 24.04.
#
# Dependencies:
#   System packages: ca-certificates, curl, file, python3
#   Python package: reportlab
#   Python package management: uv
#
#   This script checks for missing dependencies and installs them when
#   needed. uv is used for Python dependency management because isolated,
#   reproducible Python environments are best practice and avoid polluting
#   the system Python installation. uv is installed system-wide under
#   /usr/local/bin so that only one version of uv exists per system.
#
# sudo:
#   sudo is only required when system dependencies or uv are missing or when
#   uv needs to be installed/updated under /usr/local/bin. The script calls
#   sudo -v once before privileged operations so the password should only
#   need to be entered once.
#
# Label orientation:
#   Labels are generated in vertical LTO orientation: barcode to the right
#   when applied to the cartridge. This orientation is deliberately not
#   configurable. Users wanting other orientations are welcome to fork the
#   project.
#
# Printing:
#   Labels must be printed at 100% scale. Disable "Fit to Page",
#   "Shrink to Printable Area", or any other automatic scaling.
#
# Cutting:
#   Users must cut the labels themselves. A quality sharp rotary trimmer
#   paper cutter is strongly recommended.
#
# Usage:
#   ./LTO-Labels-Generator-A4-Laser-Printer-Only.sh [-h|--help]
#   ./LTO-Labels-Generator-A4-Laser-Printer-Only.sh (-6|--6|-8|--8) [-bw|--bw] [--output-dir DIR] LABEL[,LABEL...]
#
# Examples:
#   ./LTO-Labels-Generator-A4-Laser-Printer-Only.sh -8 bkup018-bkup108,TEST16-36
#   ./LTO-Labels-Generator-A4-Laser-Printer-Only.sh -6 --bw bkup018-bkup108,test16-36
#   ./LTO-Labels-Generator-A4-Laser-Printer-Only.sh -8 --output-dir /tmp/labels bkup018-bkup108
#
# Syntax:
#   - Either "-6" / "--6" or "-8" / "--8" is REQUIRED. The script aborts if
#     neither is provided or if both are provided.
#   - The optional "-bw" or "--bw" flag generates black-and-white labels
#     for monochrome laser printers. Default is color.
#   - The optional "--output-dir DIR" flag may appear anywhere before the
#     label specification. DIR must already exist and be writable.
#   - The final digit is always the LTO generation.
#   - The LTO generation digit is required in every label and range endpoint.
#   - Valid LTO generation digits are 1 through 9. Generation 0 is not
#     valid and will be rejected. For LTO generations beyond L9, pull
#     requests are welcome.
#   - Letters are case-insensitive on input and always printed uppercase.
#   - The generated VOLSER is always six characters.
#   - Prefix + zero-padded sequence becomes the six-character VOLSER.
#   - A six-letter prefix with no sequence is valid.
#
# Examples:
#   BACKUP7              -> BACKUP L7
#   bkup018              -> BKUP01 L8
#   bkup018-bkup108      -> BKUP01 L8 through BKUP10 L8
#   bk16-36              -> BK0001 L6 through BK0003 L6
#   test018-038          -> TEST01 L8 through TEST03 L8
#
# Output:
#   PDFs are written to the current working directory by default, or to
#   the directory specified by --output-dir. Filenames auto-increment:
#     LTO-Laser-Printer-Labels_01.pdf
#     LTO-Laser-Printer-Labels_02.pdf
#     ...
#     LTO-Laser-Printer-Labels_99.pdf
#   The script supports up to 99 output PDFs per directory. If all 99
#   filenames are in use, the script aborts. Delete or rename old PDFs
#   to free a slot. The 99-file cap is intentional and keeps the
#   numeric suffix two digits wide.
#
# License:
#   CC0 1.0 Universal Public Domain Dedication
#   https://creativecommons.org/publicdomain/zero/1.0/
#
# Usage example:
#   bash /absolute/path/LTO-Labels-Generator-A4-Laser-Printer-Only.sh -8 bkup018-bkup108

set -euo pipefail

OUTPUT_PREFIX="LTO-Laser-Printer-Labels"
REPO_URL="https://github.com/luckygreen/LTO-Labels-Generator-A4-Laser"

usage() {
    cat <<'USAGE'
LTO-Labels-Generator-A4-Laser-Printer-Only.sh

Generate A4 PDF sheets containing LTO tape labels for laser-printer-only
blank label sheets such as Avery 4775 / L4775.

Each PDF page fits 30 labels:
  2 labels per row
  15 rows per page
  each label is 79 mm x 17 mm

Usage:
  ./LTO-Labels-Generator-A4-Laser-Printer-Only.sh [-h|--help]
  ./LTO-Labels-Generator-A4-Laser-Printer-Only.sh (-6|--6|-8|--8) [-bw|--bw] [--output-dir DIR] LABEL[,LABEL...]

Barcode encoding (REQUIRED — choose exactly one):
  -6, --6   Six-character barcode. Encodes only the VOLSER (e.g., BKUP01).
            Use when your tape library is configured for 6-character barcode
            mode. The generation suffix is shown in the visual label cells
            but is not encoded in the barcode itself.

  -8, --8   Eight-character barcode. Encodes VOLSER + generation suffix
            (e.g., BKUP01L8). Use when your tape library is configured for
            8-character barcode mode. This matches the IBMT LTO barcode
            standard and is the format most modern libraries default to.

  WARNING: All tapes in a single library must use the same barcode encoding.
  Mixing 6-char and 8-char barcodes in the same library causes the library
  to fail to inventory or load the mismatched tapes. Check your library's
  barcode mode setting before printing a batch.

  Barcode rendering: barcodes are generated at a fixed 0.30 mm bar width and
  centered on the label. The white space on each side provides the required
  quiet zone. This meets the IBMT LTO minimum bar width of 0.254 mm (10 mil)
  for both 6-char and 8-char modes.

Other options:
  -h,  --help           Print this help and exit.
  -bw, --bw             Generate black-and-white labels for monochrome
                        laser printers. Default is color.
  --output-dir DIR      Write the PDF to DIR. DIR must already exist
                        and be writable. Default: current working directory.

Examples:
  8-char color (standard, modern libraries):
    ./LTO-Labels-Generator-A4-Laser-Printer-Only.sh -8 bkup018-bkup108,TEST16-36

  6-char B/W (older or explicitly 6-char-mode libraries):
    ./LTO-Labels-Generator-A4-Laser-Printer-Only.sh -6 --bw bkup018-bkup108,test16-36

  8-char, custom output directory:
    ./LTO-Labels-Generator-A4-Laser-Printer-Only.sh -8 --output-dir /tmp/labels bkup018-bkup108

Input syntax:
  Final digit = LTO generation
  Prefix + zero-padded sequence = six-character VOLSER
  Input capitalization does not matter; printed labels are uppercase.

Examples:
  backup7          -> BACKUP L7
  bkup018          -> BKUP01 L8
  bkup018-bkup108  -> BKUP01 L8 through BKUP10 L8
  bk16-36          -> BK0001 L6 through BK0003 L6
  test018-038      -> TEST01 L8 through TEST03 L8

Rules:
  Every label must end in an LTO generation digit.
  Every range endpoint must include an LTO generation digit.
  A six-letter prefix with no sequence is valid, e.g. BACKUP7.
  Generated VOLSER values must be exactly six characters.

Output:
  PDFs are written to the current working directory by default, or to
  the directory specified by --output-dir. Filenames auto-increment:
    LTO-Laser-Printer-Labels_01.pdf
    LTO-Laser-Printer-Labels_02.pdf
    ...
    LTO-Laser-Printer-Labels_99.pdf
  Up to 99 PDFs per directory. Delete or rename old PDFs to free a slot.

Print settings:
  Print at 100% / Actual Size.
  Disable Fit to Page, Shrink to Printable Area, or similar scaling.
  Use laser label media settings when available.

Repository:
  https://github.com/luckygreen/LTO-Labels-Generator-A4-Laser

If you find this script useful, please consider starring the repository.
USAGE
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

BW_MODE=0
BARCODE_CHARS=""
OUTPUT_DIR="$PWD"
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -6|--6)
            if [[ "$BARCODE_CHARS" == "8" ]]; then
                echo "ERROR: Cannot specify both -6 and -8." >&2
                exit 1
            fi
            BARCODE_CHARS="6"
            shift
            ;;
        -8|--8)
            if [[ "$BARCODE_CHARS" == "6" ]]; then
                echo "ERROR: Cannot specify both -6 and -8." >&2
                exit 1
            fi
            BARCODE_CHARS="8"
            shift
            ;;
        -bw|--bw)
            BW_MODE=1
            shift
            ;;
        --output-dir)
            if [[ $# -lt 2 ]]; then
                echo "ERROR: --output-dir requires a directory argument." >&2
                exit 1
            fi
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --output-dir=*)
            OUTPUT_DIR="${1#--output-dir=}"
            shift
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                POSITIONAL+=("$1")
                shift
            done
            ;;
        -*)
            echo "ERROR: Unknown option: $1" >&2
            echo "Run with -h or --help for usage." >&2
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$BARCODE_CHARS" ]]; then
    echo "ERROR: Barcode encoding is required. Specify -6 (6-char) or -8 (8-char)." >&2
    echo "All tapes in a library must use the same encoding. Check your library's barcode mode." >&2
    echo "Run with -h or --help for usage." >&2
    exit 1
fi

if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
    echo "ERROR: Missing label specification." >&2
    echo
    usage
    exit 1
fi

# -----------------------------------------------------------------------------
# Output directory validation
# -----------------------------------------------------------------------------

if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "ERROR: Output directory does not exist: $OUTPUT_DIR" >&2
    exit 1
fi

if [[ ! -w "$OUTPUT_DIR" ]]; then
    echo "ERROR: Output directory is not writable: $OUTPUT_DIR" >&2
    exit 1
fi

OUTPUT_DIR="$(readlink -f "$OUTPUT_DIR")"

# -----------------------------------------------------------------------------
# Label specification: bash-side syntactic precheck before installing deps.
# Catches obvious garbage (empty input, special chars, missing digits) so a
# typo does not trigger an apt / uv install before failing. Full semantic
# validation (range bounds, prefix matching, VOLSER length) happens in Python.
# -----------------------------------------------------------------------------

LABEL_SPEC="$(printf '%s' "${POSITIONAL[*]}" | tr ' ' ',')"

validate_label_spec() {
    local spec="$1"
    [[ -n "$spec" ]] || return 1
    [[ "$spec" =~ ^[A-Za-z0-9,-]+$ ]] || return 1
    local IFS=','
    local token left right
    for token in $spec; do
        [[ -n "$token" ]] || return 1
        if [[ "$token" == *-* ]]; then
            left="${token%-*}"
            right="${token#*-}"
            [[ "$left"  =~ ^[A-Za-z]+[0-9]+$ ]]    || return 1
            [[ "$right" =~ ^([A-Za-z]+)?[0-9]+$ ]] || return 1
        else
            [[ "$token" =~ ^[A-Za-z]+[0-9]+$ ]] || return 1
        fi
    done
    return 0
}

if ! validate_label_spec "$LABEL_SPEC"; then
    echo "ERROR: Invalid label specification: $LABEL_SPEC" >&2
    echo "Run with -h or --help for syntax." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Dependency installation
# -----------------------------------------------------------------------------

need_sudo=0
for cmd in curl file python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        need_sudo=1
    fi
done

if ! command -v uv >/dev/null 2>&1; then
    need_sudo=1
fi

if [[ "$need_sudo" -eq 1 ]]; then
    sudo -v
    sudo apt-get update -qq
    sudo apt-get install -y -qq ca-certificates curl file python3
fi

if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv systemwide under /usr/local/bin..."
    curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR="/usr/local/bin" sh
else
    if ! uv self update; then
        echo "uv self update failed; reinstalling uv systemwide under /usr/local/bin..."
        sudo -v
        curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR="/usr/local/bin" sh
    fi
fi

command -v uv >/dev/null 2>&1 || {
    echo "ERROR: uv is still unavailable after installation attempt." >&2
    exit 1
}

# -----------------------------------------------------------------------------
# Output filename allocation (caps at _99, intentional)
# -----------------------------------------------------------------------------

next_pdf_path() {
    local n candidate
    for n in $(seq -w 1 99); do
        candidate="${OUTPUT_DIR}/${OUTPUT_PREFIX}_${n}.pdf"
        if [[ ! -e "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    echo "ERROR: All filenames from ${OUTPUT_PREFIX}_01.pdf to ${OUTPUT_PREFIX}_99.pdf are taken in ${OUTPUT_DIR}." >&2
    echo "Delete or rename old PDFs to free a slot." >&2
    return 1
}

TARGET_PDF="$(next_pdf_path)"
WORKDIR="$(mktemp -d /tmp/lto-labels.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

# -----------------------------------------------------------------------------
# Python label generator (embedded, run via uv with inline metadata)
# -----------------------------------------------------------------------------

cat > "$WORKDIR/generate_lto_labels.py" <<'PY'
# /// script
# requires-python = ">=3.10"
# dependencies = ["reportlab>=4.0"]
# ///
import os
import re
from pathlib import Path

from reportlab.graphics.barcode import code39
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas

SPEC = os.environ["LABEL_SPEC"]
BW_MODE = os.environ.get("BW_MODE", "0") == "1"
# BARCODE_CHARS: "6" encodes only the VOLSER; "8" encodes VOLSER + generation suffix.
# All tapes in a library must use the same encoding to be compatible.
BARCODE_CHARS = os.environ.get("BARCODE_CHARS", "")
SCRIPT_NAME = os.environ.get("SCRIPT_NAME", "LTO-Labels-Generator-A4-Laser-Printer-Only.sh")
REPO_URL = os.environ.get("REPO_URL", "")
OUT = Path("LTO-Labels.pdf")

if BARCODE_CHARS not in ("6", "8"):
    raise SystemExit("ERROR: BARCODE_CHARS must be '6' or '8'.")

PAGE_W, PAGE_H = A4

LABEL_W = 79 * mm
LABEL_H = 17 * mm

LEFT = 18 * mm
TOP = PAGE_H - 24 * mm
BOTTOM_MARGIN = 18 * mm

ROWS_PER_PAGE = int((TOP - BOTTOM_MARGIN) // LABEL_H)
LABELS_PER_PAGE = ROWS_PER_PAGE * 2

INNER_X = 1 * mm
INNER_W = 77 * mm

BARCODE_Y = 8.5 * mm
BARCODE_H = 7.0 * mm

# Fixed bar width meeting the IBMT LTO minimum of 0.254 mm (10 mil).
# The barcode is centered on the label; white space on each side serves as
# the required quiet zone. Do NOT scale the barcode to fill the label width —
# scaling compresses 8-char barcodes below scanner threshold while 6-char
# barcodes happen to survive because they are stretched wider instead.
BAR_WIDTH = 0.30 * mm

CELL_Y = 1.0 * mm
CELL_H = 6.8 * mm
CELL_W = INNER_W / 7

COLOR_BANDS = [
    colors.HexColor("#7AC943"),
    colors.white,
    colors.HexColor("#D9E021"),
    colors.HexColor("#ED1C24"),
    colors.HexColor("#FBB03B"),
    colors.HexColor("#009245"),
    colors.white,
]

BW_BANDS = [colors.white] * 7


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def parse_label(raw: str, inherited_prefix: str | None = None) -> tuple[str, int, str]:
    value = raw.upper().strip()

    if inherited_prefix and re.fullmatch(r"\d+", value):
        value = inherited_prefix + value

    match = re.fullmatch(r"([A-Z]+)(\d+)", value)
    if not match:
        fail(f"Invalid label syntax or missing LTO generation digit: {raw}")

    prefix, digits = match.groups()
    generation = digits[-1]
    sequence_text = digits[:-1]
    sequence = int(sequence_text) if sequence_text else 0

    return prefix, sequence, generation


def build_volser(prefix: str, sequence: int, generation: str) -> tuple[str, str]:
    pad_len = 6 - len(prefix)

    if pad_len < 0:
        fail(f"Prefix too long for six-character VOLSER: {prefix}")

    if pad_len == 0:
        if sequence != 0:
            fail(f"Prefix leaves no room for sequence number: {prefix}{sequence} L{generation}")
        volser = prefix
    else:
        volser = prefix + str(sequence).zfill(pad_len)

    if len(volser) != 6:
        fail(f"Generated VOLSER is not six characters: {volser}")

    return volser, f"L{generation}"


def expand_token(token: str) -> list[tuple[str, str]]:
    token = token.strip()
    if not token:
        return []

    if "-" not in token:
        prefix, sequence, generation = parse_label(token)
        return [build_volser(prefix, sequence, generation)]

    left_raw, right_raw = token.split("-", 1)

    left_prefix, left_sequence, left_generation = parse_label(left_raw)
    right_prefix, right_sequence, right_generation = parse_label(
        right_raw,
        inherited_prefix=left_prefix,
    )

    if left_prefix != right_prefix:
        fail(f"Range prefix mismatch: {token}")

    if left_generation != right_generation:
        fail(f"Range LTO generation mismatch: {token}")

    if right_sequence < left_sequence:
        fail(f"Descending ranges are not supported: {token}")

    return [
        build_volser(left_prefix, sequence, left_generation)
        for sequence in range(left_sequence, right_sequence + 1)
    ]


LABELS: list[tuple[str, str]] = []
for item in SPEC.split(","):
    LABELS.extend(expand_token(item))

if not LABELS:
    fail("No labels generated.")


def draw_label(pdf: canvas.Canvas, x: float, y: float, volser: str, generation: str) -> None:
    pdf.setStrokeColor(colors.HexColor("#888888"))
    pdf.setLineWidth(0.2)
    pdf.rect(x, y, LABEL_W, LABEL_H, stroke=1, fill=0)

    # 6-char mode: barcode encodes only the VOLSER (e.g., BKUP01).
    # 8-char mode: barcode encodes VOLSER + generation suffix (e.g., BKUP01L8).
    # The visual label cells always show all seven characters regardless of mode.
    barcode_data = volser if BARCODE_CHARS == "6" else volser + generation

    barcode = code39.Standard39(
        barcode_data,
        barHeight=BARCODE_H,
        barWidth=BAR_WIDTH,
        checksum=0,
        stop=1,
        quiet=0,
        humanReadable=0,
    )

    # Center the barcode horizontally on the label. The white space on each
    # side is the quiet zone — do not add scaling that would eliminate it.
    barcode_x = x + (LABEL_W - barcode.width) / 2
    pdf.saveState()
    pdf.translate(barcode_x, y + BARCODE_Y)
    barcode.drawOn(pdf, 0, 0)
    pdf.restoreState()

    bands = BW_BANDS if BW_MODE else COLOR_BANDS

    for index, text in enumerate(list(volser) + [generation]):
        cell_x = x + INNER_X + index * CELL_W
        cell_y = y + CELL_Y

        pdf.setFillColor(bands[index])
        pdf.rect(cell_x, cell_y, CELL_W, CELL_H, stroke=1, fill=1)

        pdf.setFillColor(colors.black)
        pdf.setFont("Helvetica-Bold", 10)
        pdf.drawCentredString(cell_x + CELL_W / 2, cell_y + 2 * mm, text)


pdf = canvas.Canvas(str(OUT), pagesize=A4)

pdf.setTitle("LTO Tape Labels")
pdf.setAuthor(SCRIPT_NAME)
pdf.setSubject(f"Generated by {SCRIPT_NAME}")
pdf.setKeywords("LTO, tape labels, Avery 4775, L4775, laser printer")
if REPO_URL:
    pdf.setCreator(REPO_URL)

for page_start in range(0, len(LABELS), LABELS_PER_PAGE):
    page_labels = LABELS[page_start:page_start + LABELS_PER_PAGE]
    row_count = (len(page_labels) + 1) // 2

    for index, (volser, generation) in enumerate(page_labels):
        row, column = divmod(index, 2)
        x = LEFT + column * LABEL_W
        y = TOP - LABEL_H - row * LABEL_H
        draw_label(pdf, x, y, volser, generation)

    pdf.setStrokeColor(colors.black)
    pdf.setLineWidth(0.3)

    for row in range(row_count + 1):
        y = TOP - row * LABEL_H
        pdf.line(0, y, PAGE_W, y)

    for x in [LEFT, LEFT + LABEL_W, LEFT + 2 * LABEL_W]:
        pdf.line(x, 0, x, PAGE_H)

    pdf.showPage()

pdf.save()

if not OUT.exists() or OUT.stat().st_size < 1000:
    fail("PDF generation failed.")

pages = (len(LABELS) + LABELS_PER_PAGE - 1) // LABELS_PER_PAGE
color_mode = "B/W" if BW_MODE else "color"
print(f"Generated {len(LABELS)} labels across {pages} page(s), mode={color_mode}, barcode={BARCODE_CHARS}-char.")
PY

# -----------------------------------------------------------------------------
# Run the Python generator and place the resulting PDF
# -----------------------------------------------------------------------------

cd "$WORKDIR"
LABEL_SPEC="$LABEL_SPEC" \
BW_MODE="$BW_MODE" \
BARCODE_CHARS="$BARCODE_CHARS" \
SCRIPT_NAME="$(basename "$0")" \
REPO_URL="$REPO_URL" \
uv run "$WORKDIR/generate_lto_labels.py"

cp "$WORKDIR/LTO-Labels.pdf" "$TARGET_PDF"

file "$TARGET_PDF" | grep -qi 'pdf' || {
    echo "ERROR: Not detected as PDF: $TARGET_PDF" >&2
    exit 1
}

ls -lh "$TARGET_PDF"
echo "Completed: $TARGET_PDF"
