#!/bin/sh
# Install the speaker CLI

set -e

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.speaker"
BASE_URL="https://raw.githubusercontent.com/migsterrrrr/speaker-cli/main"


echo "Installing speaker CLI..."

# Download CLI
curl -sL "$BASE_URL/speaker" -o "$INSTALL_DIR/speaker"
chmod +x "$INSTALL_DIR/speaker"

# Download agent docs
mkdir -p "$CONFIG_DIR"
curl -sL "$BASE_URL/SPEAKER.md" -o "$CONFIG_DIR/SPEAKER.md"

echo ""
echo "  ✓ speaker installed to $INSTALL_DIR/speaker"
echo "  ✓ Agent docs saved to $CONFIG_DIR/SPEAKER.md"
echo ""
echo "  Get started:"
echo "    speaker signup          Create an account"
echo "    speaker help            See all commands"
echo ""
