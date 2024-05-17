#!/usr/bin/env bash
set -e
REFIND_GUI_DIR="${HOME}/.local/rEFInd_GUI/GUI"
REFIND_BOOT_DIR="/boot/efi/EFI/refind"

if [[ ! -d "${REFIND_GUI_DIR}" ]]; then
  echo "${REFIND_GUI_DIR}: No such directory!"
  exit 1
fi

if [[ ! -d "${REFIND_BOOT_DIR}" ]]; then
  echo "${REFIND_BOOT_DIR} No such directory!"
  exit 1
fi

cp "${HOME}"/.local/rEFInd_GUI/GUI/{refind.conf,background.png,os_icon1.png,os_icon2.png,os_icon3.png,os_icon4.png} /boot/efi/EFI/refind/
