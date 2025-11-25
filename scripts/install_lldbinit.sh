#!/usr/bin/env bash
# install_lldbinit.sh
# Script to install .lldbinit file to configure LLDB to not stop on SIGSTOP
# when the app is backgrounded on macOS/iOS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LLDBINIT_SOURCE="$REPO_ROOT/.lldbinit"
LLDBINIT_TARGET="$HOME/.lldbinit"

echo "Installing .lldbinit to $LLDBINIT_TARGET"

if [ ! -f "$LLDBINIT_SOURCE" ]; then
  echo "Error: $LLDBINIT_SOURCE not found. Create the project .lldbinit first." >&2
  exit 1
fi

# Copy the project .lldbinit to the user's home
cp "$LLDBINIT_SOURCE" "$LLDBINIT_TARGET"

echo "Installation complete."
echo
echo "You can verify the contents with:"
echo "  cat $LLDBINIT_TARGET"
echo
echo "Or edit it with:"
echo "  code $LLDBINIT_TARGET"
echo
echo "Restart your terminal or IDE to ensure LLDB picks up the new configuration."
echo
echo "To verify LLDB is handling signals correctly, you can run an LLDB session and check:"
echo "  (lldb) process handle SIGSTOP"
echo "It should show: stop: false, pass: true, notify: false"
echo "Similarly check SIGTSTP, SIGTTIN, and SIGTTOU."
echo
echo "Done."
