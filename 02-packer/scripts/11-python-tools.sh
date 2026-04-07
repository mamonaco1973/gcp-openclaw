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
