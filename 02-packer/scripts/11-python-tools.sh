#!/bin/bash
set -euo pipefail

# ================================================================================
# Python Tools + System Utilities
# ================================================================================
#
# Installs a broad set of tools useful for an AI agent working with documents,
# data, web content, and media files.
#
# ================================================================================

export DEBIAN_FRONTEND=noninteractive

echo "NOTE: [python-tools] installing system utilities"
apt-get install -y \
  poppler-utils \
  imagemagick \
  pandoc \
  sqlite3 \
  ffmpeg \
  ghostscript \
  xmlstarlet \
  csvkit \
  msmtp \
  msmtp-mta \
  mailutils

# httpx/anyio now require typing_extensions >= 4.16, but apt ships 4.10 with
# no RECORD file, so pip aborts rather than uninstall it. Land a newer copy
# in /usr/local first -- it precedes dist-packages on sys.path, so imports
# resolve to it while apt's copy stays in place for Debian's own packages.
echo "NOTE: [python-tools] pre-staging typing_extensions over the apt copy"
pip3 install --break-system-packages --ignore-installed typing_extensions

echo "NOTE: [python-tools] installing Python packages system-wide"
pip3 install --break-system-packages \
  python-docx \
  python-pptx \
  openpyxl \
  pandas \
  numpy \
  matplotlib \
  pillow \
  pymupdf \
  reportlab \
  beautifulsoup4 \
  lxml \
  requests \
  tabulate \
  rich \
  arrow \
  httpx

echo "NOTE: [python-tools] done"
