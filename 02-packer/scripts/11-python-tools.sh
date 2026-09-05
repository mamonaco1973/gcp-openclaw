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

# The six Python libraries below come from apt, not pip. The base image
# already ships them, so pip silently skipped them; listing them here makes
# that dependency explicit. Do NOT move them into the pip pins -- pip would
# then install over apt's copies and hit the RECORD conflict described
# below, once per package.
echo "NOTE: [python-tools] installing apt-provided Python libraries"
apt-get install -y \
  python3-openpyxl \
  python3-pil \
  python3-bs4 \
  python3-lxml \
  python3-requests \
  python3-rich

# Versions are pinned to a build verified working on 2026-09-05. Without
# pins pip resolves "newest on PyPI at build time", so an upstream release
# can break a build that changed nothing -- which is exactly how anyio
# 4.15 broke this script by requiring typing_extensions >= 4.16.
#
# typing_extensions is staged separately, first, with --ignore-installed:
# apt ships 4.10 with no RECORD file, so pip cannot uninstall it and aborts
# the whole transaction. Installing over it puts the new copy in /usr/local,
# which precedes dist-packages on sys.path, leaving apt's copy intact for
# Debian's own dependents. The flag is NOT used on the main install -- there
# it would stop apt-provided packages from satisfying transitive deps, so
# pip would pull unpinned copies of packaging, pillow, dateutil and pyparsing.
#
# To refresh: build an image, then on the host run
#   pip3 list --format=freeze --path /usr/local/lib/python3.12/dist-packages
# and paste the output into the heredoc below.
echo "NOTE: [python-tools] installing pinned Python packages system-wide"
cat > /tmp/python-tools-requirements.txt <<'REQEOF'
anyio==4.15.1
arrow==1.4.0
charset-normalizer==3.5.1
contourpy==1.3.3
cycler==0.12.1
fonttools==4.64.0
h11==0.16.0
httpcore==1.0.9
httpx==0.28.1
kiwisolver==1.5.1
matplotlib==3.11.1
numpy==2.5.2
pandas==3.0.5
pymupdf==1.28.2
python-docx==1.2.0
python-pptx==1.0.2
reportlab==5.0.1
tabulate==0.10.0
typing_extensions==4.16.0
tzdata==2026.3
xlsxwriter==3.2.9
REQEOF

pip3 install --break-system-packages --ignore-installed \
  typing_extensions==4.16.0

pip3 install --break-system-packages -r /tmp/python-tools-requirements.txt
rm -f /tmp/python-tools-requirements.txt

echo "NOTE: [python-tools] done"
