#!/bin/bash
set -e

USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}

BROWSER_BOX_USER=${BROWSER_BOX_USER:-browser}
BROWSER_BOX_REPO=${BROWSER_BOX_REPO:-sameersbn}
BROWSER_BOX_VERSION=${BROWSER_BOX_VERSION:-1.0.1}

install_browser_box() {
  echo "Installing browser-box..."
  install -m 0755 /var/cache/browser-box/browser-box /target/
  echo "Installing google-chrome..."
  ln -sf browser-box /target/google-chrome
  echo "Installing google-chrome-stable..."
  ln -sf browser-box /target/google-chrome-stable
  echo "Installing tor-browser..."
  ln -sf browser-box /target/tor-browser
  echo "Installing chromium-browser..."
  ln -sf browser-box /target/chromium-browser
  echo "Installing firefox..."
  ln -sf browser-box /target/firefox
  echo "Installing url luancher..."
  ln -sf browser-box /target/browser-exec
  if [ "${BROWSER_BOX_USER}" != "browser" ] && [ -n "${BROWSER_BOX_USER}" ]; then
    echo "Updating user to ${BROWSER_BOX_USER}..."
    sed -i -e s%"BROWSER_BOX_USER:-browser"%"BROWSER_BOX_USER:-${BROWSER_BOX_USER}"%1 /target/browser-box
  fi
  if [[ -n "${BROWSER_BOX_VERSION}" ]]; then
    echo "Updating version to ${BROWSER_BOX_VERSION}..."
    sed -i -e s%"BROWSER_BOX_VERSION:-.*$"%"BROWSER_BOX_VERSION:-${BROWSER_BOX_VERSION}}"%1 /target/browser-box
  fi
  if [[ -n "${CHROME_USERDATA}" ]]; then
    echo "Updating Chrome user volume..."
    sed -i -e s%"CHROME_USERDATA=.*$"%"CHROME_USERDATA\=${CHROME_USERDATA}"%1 /target/browser-box
  fi
  if [[ -n "${FIREFOX_USERDATA}" ]]; then
    echo "Updating FireFox user volume..."
    sed -i -e s%"FIREFOX_USERDATA=.*$"%"FIREFOX_USERDATA\=${FIREFOX_USERDATA}"%1 /target/browser-box
  fi
  sed -i -e s%"\(BROWSER_BOX_REPO=\).*$"%"\1${BROWSER_BOX_REPO}"%1 /target/browser-box

}

uninstall_browser_box() {
  echo "Uninstalling browser-box..."
  rm -rf /target/browser-box
  echo "Uninstalling google-chrome..."
  rm -rf /target/google-chrome
  echo "Uninstalling google-chrome-stable..."
  rm -rf /target/google-chrome-stable
  echo "Uninstalling tor-browser..."
  rm -rf /target/tor-browser
  echo "Uninstalling chromium-browser..."
  rm -rf /target/chromium-browser
  echo "Uninstalling firefox..."
  rm -rf /target/firefox
  echo "Uninstalling url launcher..."
  rm -rf /target/browser-exec
}

create_user() {
  exist=$(getent passwd ${USER_UID} >/dev/null 2>&1 || echo false)
  if [ x${exist} != "xfalse" ]; then
    echo "Warning: User ID ${USER_UID} exists in Browser Box"
    BROWSER_BOX_USER=$(getent passwd ${USER_UID} | cut -d ":" -f 1)
    if [ ! -d /home/${BROWSER_BOX_USER} ]; then
      mkdir /home/${BROWSER_BOX_USER}
    fi
  fi
  # ensure home directory is owned by browser
  # and that profile files exist
  if [[ -d /home/${BROWSER_BOX_USER} ]]; then
    chown ${USER_UID}:${USER_GID} /home/${BROWSER_BOX_USER}
    # copy user files from /etc/skel
    cp /etc/skel/.bashrc /home/${BROWSER_BOX_USER}
    cp /etc/skel/.bash_logout /home/${BROWSER_BOX_USER}
    cp /etc/skel/.profile /home/${BROWSER_BOX_USER}
    chown ${USER_UID}:${USER_GID} \
        /home/${BROWSER_BOX_USER}/.bashrc \
        /home/${BROWSER_BOX_USER}/.profile \
        /home/${BROWSER_BOX_USER}/.bash_logout
  fi
  # create group with USER_GID
  if ! getent group ${BROWSER_BOX_USER} >/dev/null; then
    groupadd -f -g ${USER_GID} ${BROWSER_BOX_USER} 2> /dev/null
  fi

  # create user with USER_UID
  if ! getent passwd ${BROWSER_BOX_USER} >/dev/null; then
    adduser --disabled-login --uid ${USER_UID} --gid ${USER_GID} \
      --gecos 'Browser Box' ${BROWSER_BOX_USER}
  fi

  # fixes issue #7
  chown -R ${BROWSER_BOX_USER}: /usr/lib/tor-browser
}

grant_access_to_video_devices() {
  for device in /dev/video*
  do
    if [[ -c $device ]]; then
      VIDEO_GID=$(stat -c %g $device)
      VIDEO_GROUP=$(stat -c %G $device)
      if [[ ${VIDEO_GROUP} == "UNKNOWN" ]]; then
        VIDEO_GROUP=browser-box-video
        groupadd -g ${VIDEO_GID} ${VIDEO_GROUP}
      fi
      usermod -a -G ${VIDEO_GROUP} ${BROWSER_BOX_USER}
      break
    fi
  done
}

launch_browser() {
  cd /home/${BROWSER_BOX_USER}
  exec sudo -HEu ${BROWSER_BOX_USER} PULSE_SERVER=/run/pulse/native $@ ${extra_opts}
}

case "$1" in
  install)
    install_browser_box
    ;;
  uninstall)
    uninstall_browser_box
    ;;
  google-chrome|google-chrome-stable|tor-browser|chromium-browser|firefox)
    create_user
    grant_access_to_video_devices
    launch_browser $@
    ;;
  *)
    exec $@
    ;;
esac
