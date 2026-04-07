#!/bin/bash
set -euo pipefail

# ================================================================================
# LXQt Desktop
# ================================================================================

export DEBIAN_FRONTEND=noninteractive

echo "NOTE: [lxqt] installing Xvfb for headless browser support"
apt-get update -y
apt-get install -y xvfb

echo "NOTE: [lxqt] installing LXQt desktop environment"
apt-get update -y
apt-get install -y \
  lxqt \
  lxqt-core \
  lxqt-config \
  lxqt-panel \
  lxqt-session \
  lxqt-policykit \
  lxqt-sudo \
  lxqt-runner \
  lxqt-notificationd \
  openbox \
  obconf-qt \
  pcmanfm-qt \
  qterminal \
  papirus-icon-theme

echo "NOTE: [lxqt] removing cloud-irrelevant and XRDP-conflicting packages"
apt-get purge -y \
  bluez \
  blueman \
  bluetooth \
  cups \
  cups-browsed \
  cups-common \
  cups-core-drivers \
  cups-daemon \
  cups-filters \
  system-config-printer \
  system-config-printer-common \
  hplip \
  modemmanager \
  simple-scan \
  sane-utils \
  speech-dispatcher \
  speech-dispatcher-audio-plugins \
  orca \
  gvfs \
  gvfs-backends \
  gvfs-fuse \
  lxqt-powermanagement \
  libreoffice* \
  liblibreoffice* \
  update-notifier \
  update-notifier-common \
  ubuntu-advantage-desktop-daemon \
  2>/dev/null || true
apt-get autoremove -y

echo "NOTE: [lxqt] configuring LXQt session defaults"
mkdir -p /etc/xdg/lxqt
cat > /etc/xdg/lxqt/session.conf <<'EOF'
[Environment]
BROWSER=google-chrome
TERM=qterminal

[General]
window_manager=openbox
EOF

echo "NOTE: [lxqt] configuring panel"
cat > /etc/xdg/lxqt/panel.conf <<'EOF'
[General]
iconTheme=Papirus-Dark

[kbindicator]
alignment=Right
type=kbindicator

[quicklaunch]
alignment=Left
apps\1\desktop=/usr/share/applications/google-chrome.desktop
apps\2\desktop=/usr/share/applications/qterminal.desktop
apps\3\desktop=/usr/share/applications/openclaw.desktop
apps\4\desktop=/usr/share/applications/pcmanfm-qt.desktop
apps\size=4
type=quicklaunch

[quicklaunch2]
alignment=left
apps\1\desktop=/usr/share/applications/lxqt-leave.desktop
apps\size=1
type=quicklaunch

[panel1]
plugins=mainmenu, showdesktop, desktopswitch, quicklaunch, taskbar, tray, statusnotifier, worldclock, quicklaunch2

[taskbar]
buttonWidth=200
raiseOnCurrentDesktop=true
EOF

echo "NOTE: [lxqt] configuring pcmanfm-qt desktop"
mkdir -p /etc/xdg/pcmanfm-qt/lxqt
cat > /etc/xdg/pcmanfm-qt/lxqt/settings.conf <<'EOF'
[Desktop]
Wallpaper=/usr/share/lxqt/themes/debian/wallpaper.svg
WallpaperMode=zoom
WallpaperRandomize=false
ShowTrash=false
ShowMounts=false

[System]
Terminal=qterminal

[Behavior]
QuickExec=true
EOF

echo "NOTE: [lxqt] configuring skel for new users"
mkdir -p /etc/skel/.config/lxqt
cat > /etc/skel/.config/lxqt/session.conf <<'EOF'
[General]
window_manager=openbox
EOF

cat > /etc/skel/.config/lxqt/panel.conf <<'EOF'
[General]
iconTheme=Papirus-Dark

[kbindicator]
alignment=Right
type=kbindicator

[quicklaunch]
alignment=Left
apps\1\desktop=/usr/share/applications/google-chrome.desktop
apps\2\desktop=/usr/share/applications/qterminal.desktop
apps\3\desktop=/usr/share/applications/openclaw.desktop
apps\4\desktop=/usr/share/applications/pcmanfm-qt.desktop
apps\size=4
type=quicklaunch

[quicklaunch2]
alignment=left
apps\1\desktop=/usr/share/applications/lxqt-leave.desktop
apps\size=1
type=quicklaunch

[panel1]
plugins=mainmenu, showdesktop, desktopswitch, quicklaunch, taskbar, tray, statusnotifier, worldclock, quicklaunch2

[taskbar]
buttonWidth=200
raiseOnCurrentDesktop=true
EOF

mkdir -p /etc/skel/.config/pcmanfm-qt/lxqt
cat > /etc/skel/.config/pcmanfm-qt/lxqt/settings.conf <<'EOF'
[Desktop]
Wallpaper=/usr/share/lxqt/themes/debian/wallpaper.svg
WallpaperMode=zoom
WallpaperRandomize=false
ShowTrash=false
ShowMounts=false

[Behavior]
QuickExec=true
EOF

echo "NOTE: [lxqt] pre-seeding Chrome first-run sentinel for new users"
mkdir -p "/etc/skel/.config/google-chrome"
touch "/etc/skel/.config/google-chrome/First Run"

echo "NOTE: [lxqt] done"
