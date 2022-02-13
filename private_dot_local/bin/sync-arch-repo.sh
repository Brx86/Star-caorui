function sync_arch_repo() {
  local REPO_NAME BASE_URL SAVE_PATH PKG_LIST DELETE_LIST
  REPO_NAME=$1;
  BASE_URL=$2;
  SAVE_PATH=/srv/http/.local/state/cos/archlinux

  PKG_LIST=`curl -skL ${BASE_URL}/${REPO_NAME}.db | bsdtar xf - -O | awk '/%FILENAME%/{getline;print}'`;
  for PKG_NAME in ${PKG_LIST}; do
    echo Downloading ${PKG_NAME};
    if [[ ! -d ${SAVE_PATH} ]]; then
      mkdir -p ${SAVE_PATH}
    fi
    wget --no-check-certificate -c -N -q ${BASE_URL}/${PKG_NAME} -P ${SAVE_PATH}/${REPO_NAME}
    wget --no-check-certificate -c -N -q ${BASE_URL}/${PKG_NAME}.sig -P ${SAVE_PATH}/${REPO_NAME}
  done
  DELETE_LIST=`find ${SAVE_PATH}/${REPO_NAME} -type f | grep -E \.pkg\.tar\..*\.part`
  if [[ ${DELETE_LIST} ]]; then
    echo %{DELETE_LIST} | xargs rm -r
  fi
}
