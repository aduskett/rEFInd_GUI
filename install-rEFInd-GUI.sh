#!/usr/bin/env bash
set -e

# A simple script to install the rEFInd customization GUI
BUILD_DIR=$(mktemp -d)
GIT_DIR="${BUILD_DIR}"/rEFInd_GUI
BAZZITE="/etc/bazzite/image_name"
FEDORA_BASE=$(command -v dnf || true)
USER="$(whoami)"

if [[ "${EUID}" == 0 ]]; then
  echo "Do not run this script as root!"
  exit 1
fi


message() {
  printf "\n##### %s #####\n" "${1}"
}


clone() {
  message "Cloning https://github.com/jlobue10/rEFInd_GUI to ${GIT_DIR}"
  if [[ ! -d "${GIT_DIR}" ]]; then
    cd "${BUILD_DIR}"
    git clone https://github.com/jlobue10/rEFInd_GUI
  fi
}


copy_local_files() {
  local_dir="${HOME}"/.local/rEFInd_GUI
  message "Copying rEFInd_GUI files to ${local_dir}"
  rm -rf "${local_dir}" && mkdir -p "${local_dir}"
  # Directories
  cp -dprf "${GIT_DIR}"/{GUI,icons,backgrounds} "${local_dir}"/
  # Hard links
  cp -f "${GIT_DIR}"/{refind_install_package_mgr.sh,refind_install_Sourceforge.sh} "${local_dir}"/
  cp -f "${GIT_DIR}"/refind-GUI.conf "${local_dir}"/GUI/refind.conf
  chmod +x "${local_dir}"/{refind_install_package_mgr.sh,refind_install_Sourceforge.sh}
}


install_fedora_dependencies() {
  i=0
  rpms=("${@}")
  declare -A not_installed
  for rpm in "${rpms[@]}"; do
    check=$(dnf list --installed |grep "${rpm}" || true)
    if [[ -z "${check}" ]]; then
      not_installed[${i}]="${rpm}"
      i=$(( "${i}" + 1 ))
    fi
  done
  if [[ "${i}" -gt 0 ]]; then
    echo "Installing: ${not_installed[*]}"
    sudo dnf install -y "${not_installed[*]}"
  fi
  check=$(sudo dnf list --installed | grep "rEFInd_GUI" || true)
  if [[ -z "${check}" ]]; then
    sudo dnf remove -y rEFInd_GUI
  fi
}


rpm_build() {
  rpmbuild_dir="${HOME}"/rpmbuild/
  rm -rf "${rpmbuild_dir}"
  mkdir -p "${rpmbuild_dir}"/{SPECS,SOURCES}
  cp "${GIT_DIR}"/rEFInd_GUI.spec "${HOME}"/rpmbuild/SPECS
  cd "${rpmbuild_dir}"
  rpmbuild -bb "${HOME}"/rpmbuild/SPECS/rEFInd_GUI.spec
  sudo dnf install -y "${HOME}"/rpmbuild/RPMS/x86_64/rEFInd_GUI*.rpm
}


build_fedora() {
  message 'Fedora based installation starting.'
  rpms=( "cmake" "hwinfo" "gcc-c++" "git" "qt5-qtbase-devel" "qt5-qttools-devel" "rpm-build" "wget" )
  install_fedora_dependencies "${rpms[@]}"
  rpm_build
}

clone
copy_local_files

if [[ -n "${FEDORA_BASE}" ]] && [[ -e "${BAZZITE}" ]]; then
  build_fedora
fi

if [[ -e "${BAZZITE}" ]]; then
  message 'Bazzite based installation starting.'
  check=$(rpm-ostree status | grep xterm || true)
  if [[ -z "${check}" ]]; then
    sudo rpm-ostree install xterm
  fi
  cd "${HOME}"/Downloads
  rm -f rEFInd_GUI*.rpm
  latest_rpm="$(curl -s https://api.github.com/repos/jlobue10/rEFInd_GUI/releases/latest | grep "browser_download_url.*\.rpm" | grep -v "\.src\.rpm" | cut -d : -f 2,3 | tr -d \"\ || true)"
  if [[ -n "${latest_rpm}" ]]; then
    wget "${latest_rpm}"
    sudo rpm-ostree install ./"${latest_rpm}"
  else
    message "Unable to get the latest rEFINd_GUI!"
    exit 1
  fi
fi   

sed -i "s@USER@${USER}@g" "${GIT_DIR}"/install_config_from_GUI
sed -i "s@HOME@/home/${USER}@g" "${GIT_DIR}"/rEFInd_GUI.desktop
sed -i "s@HOME@/home/${USER}@g" "${GIT_DIR}"/install_config_from_GUI.sh
sed -i "s@USER@${USER}@g" "${GIT_DIR}"/rEFInd_bg_randomizer.sh

sudo mkdir -p /etc/rEFInd
sudo cp -f "${GIT_DIR}"/install_config_from_GUI /etc/sudoers.d/install_config_from_GUI
sudo cp -f "${GIT_DIR}"/install_config_from_GUI.sh /etc/rEFInd/install_config_from_GUI.sh
sudo cp -f "${GIT_DIR}"/rEFInd_bg_randomizer.sh /etc/rEFInd/rEFInd_bg_randomizer.sh
sudo cp -f "${GIT_DIR}"/GUI/UEFI_icon.png /etc/rEFInd/UEFI_icon.png

if [[ -e "${BAZZITE}" ]]; then
  sudo cp -f "${GIT_DIR}"/rEFInd_GUI.desktop /etc/rEFInd/rEFInd_GUI.desktop
  sudo chmod +x /etc/rEFInd/rEFInd_GUI.desktop
  cp "${GIT_DIR}"/rEFInd_GUI.desktop "${HOME}"/Desktop/refind_GUI.desktop
  cp "${GIT_DIR}"/.Xresources "${HOME}"/.Xresources
  xrdb "${HOME}"/.Xresources
else
  sudo cp -f "${GIT_DIR}"/rEFInd_GUI.desktop /usr/share/applications/rEFInd_GUI.desktop
  cp /usr/share/applications/rEFInd_GUI.desktop "${HOME}"/Desktop/refind_GUI.desktop
fi

chmod +x "${HOME}"/Desktop/refind_GUI.desktop
sudo chmod +x /etc/rEFInd/{install_config_from_GUI.sh,rEFInd_bg_randomizer.sh}

if [[ -e "${BAZZITE}" ]]; then
   systemctl reboot
fi
