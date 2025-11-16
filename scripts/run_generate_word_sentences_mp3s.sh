#!/usr/bin/env bash
# run_generate_word_sentences_mp3s.sh
# Lightweight helper to create/use a Python venv, ensure `elevenlabs` is installed,
# and run scripts/generate_word_sentences_mp3s.py.
# Usage: ./scripts/run_generate_word_sentences_mp3s.sh [--venv /path/to/venv] [--pip-extra-args "..."] [-- python-args]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="${VENV_DIR:-$REPO_ROOT/.venv}"  # default venv inside repo
PYTHON=${PYTHON:-python3}
PIP_EXTRA_ARGS=${PIP_EXTRA_ARGS:-}

show_help(){
  cat <<-EOF
Usage: ${0##*/} [--venv /path/to/venv] [--python /path/to/python] [--pip-extra-args "..."] [--] [args...]

This script ensures a virtualenv exists, installs 'elevenlabs' into it (if missing),
then runs scripts/generate_word_sentences_mp3s.py with any extra args forwarded.

Examples:
  ./scripts/run_generate_word_sentences_mp3s.sh
  ./scripts/run_generate_word_sentences_mp3s.sh -- pip_arg1 pip_arg2
  VENV_DIR=/tmp/myenv ./scripts/run_generate_word_sentences_mp3s.sh

EOF
}

# parse simple flags
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --venv)
      VENV_DIR="$2"; shift 2;;
    --python)
      PYTHON="$2"; shift 2;;
    --pip-extra-args)
      PIP_EXTRA_ARGS="$2"; shift 2;;
    -h|--help)
      show_help; exit 0;;
    --)
      shift; POSITIONAL+=("$@"); break;;
    -*|--*)
      echo "Unknown option $1"; show_help; exit 1;;
    *)
      POSITIONAL+=("$1"); shift;;
  esac
done

# Remaining args forwarded to python script
# Be defensive: when `set -u` is enabled, expanding an unset array can trigger
# an "unbound variable" error on some shells. Ensure POSITIONAL is declared
# and only call `set --` with elements when present.
declare -a POSITIONAL
if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  set -- "${POSITIONAL[@]}"
else
  set --
fi

echo "Using Python executable: ${PYTHON}"

# Ensure python exists
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "ERROR: Python executable '$PYTHON' not found. Install Python 3 and retry." >&2
  exit 2
fi

# Create venv if not exists
if [[ ! -d "$VENV_DIR" ]]; then
  echo "Creating virtualenv at: $VENV_DIR"
  "$PYTHON" -m venv "$VENV_DIR"
fi

# Activate venv in a subshell
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"

# Upgrade pip/setuptools wheel to reduce installer issues
python -m pip install --upgrade pip setuptools wheel >/dev/null

REQ_FILE="$REPO_ROOT/scripts/requirements.txt"
if [[ -f "$REQ_FILE" ]]; then
  echo "Installing packages from: $REQ_FILE"
  python -m pip install -r "$REQ_FILE" $PIP_EXTRA_ARGS
  # Only install packages from requirements.txt; do not install individual packages here.
  python -m pip install -r "$REQ_FILE" $PIP_EXTRA_ARGS
else
  echo "ERROR: requirements.txt not found at $REQ_FILE; this script installs only from requirements.txt" >&2
  deactivate || true
  exit 1
fi

# Print version for transparency
python -c "import elevenlabs as e; print('elevenlabs', getattr(e, '__version__', 'unknown'))" || true

# Run the target script
PY_SCRIPT="$REPO_ROOT/scripts/generate_word_sentences_mp3s.py"
if [[ ! -f "$PY_SCRIPT" ]]; then
  echo "ERROR: expected script not found: $PY_SCRIPT" >&2
  deactivate || true
  exit 3
fi

echo "Running: $PY_SCRIPT $*"
python "$PY_SCRIPT" "$@"

# Deactivate venv (no-op if subshell)
deactivate || true

exit 0
