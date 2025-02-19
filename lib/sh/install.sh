#!/usr/bin/env sh

trap 'rm -rf "$WORKDIR"' EXIT INT
WORKDIR="$(mktemp -d)"
ZOPT=""
AOPT=""
BOPT="main"
while getopts ":i:a:b:" opt; do
  case ${opt} in
  i)
    ZOPT="${ZOPT}$OPTARG"
    ;;
  a)
    AOPT="${AOPT}$OPTARG"
    ;;
  b)
    BOPT="$OPTARG"
    ;;
  \?)
    echo "Invalid option: $OPTARG" 1>&2
    ;;
  :)
    echo "Invalid option: $OPTARG requires an argument" 1>&2
    ;;
  esac
done
shift $((OPTIND - 1))

#if [ -z "$BOPT" ]; then
#BOPT="main"
#fi

if [ "$AOPT" = loader ]; then
  ZI_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zi"
  command mkdir -p "$ZI_CONFIG_DIR"
  if command -v curl >/dev/null 2>&1; then
    command curl -fsSL https://raw.githubusercontent.com/z-shell/zi-src/main/lib/zsh/init.zsh -o "${ZI_CONFIG_DIR}/init.zsh"
  elif command -v wget >/dev/null 2>&1; then
    command wget -qO "${ZI_CONFIG_DIR}/init.zsh" https://raw.githubusercontent.com/z-shell/zi-src/main/lib/zsh/init.zsh
  fi
  command chmod a+x "${ZI_CONFIG_DIR}/init.zsh"
  command sed -i "s/branch=\"main\"/branch=\"$BOPT\"/g" "${ZI_CONFIG_DIR}/init.zsh"
fi

if [ -z "$ZI_HOME" ]; then
  ZI_HOME="${ZDOTDIR:-$HOME}/.zi"
fi

if [ -z "$ZI_BIN_DIR_NAME" ]; then
  ZI_BIN_DIR_NAME="bin"
fi

if ! test -d "$ZI_HOME"; then
  command mkdir "$ZI_HOME"
  command chmod g-w "$ZI_HOME"
  command chmod o-w "$ZI_HOME"
fi

if ! command -v git >/dev/null 2>&1; then
  printf '%s\n' "[1;31m▓▒░[0m Something went wrong: no [1;32mgit[0m available, cannot proceed."
  exit 1
fi

# Get the download-progress bar tool
if command -v curl >/dev/null 2>&1; then
  command mkdir -p /tmp/zi
  cd /tmp/zi || return
  command curl -fsSLO https://raw.githubusercontent.com/z-shell/zi/main/lib/zsh/git-process-output.zsh &&
    command chmod a+x /tmp/zi/git-process-output.zsh
elif command -v wget >/dev/null 2>&1; then
  command mkdir -p /tmp/zi
  cd /tmp/zi || return
  command wget -q https://raw.githubusercontent.com/z-shell/zi/main/lib/zsh/git-process-output.zsh &&
    command chmod a+x /tmp/zi/git-process-output.zsh
fi

if test -d "${ZI_HOME}/${ZI_BIN_DIR_NAME}/.git"; then
  cd "${ZI_HOME}/${ZI_BIN_DIR_NAME}" || return
  printf '%s\n' "[1;34m▓▒░[0m Updating [1;36m(z-shell/zi)[1;33m plugin manager[0m at [1;35m${ZI_HOME}/${ZI_BIN_DIR_NAME}[0m"
  command git clean -d -f -f
  command git reset --hard HEAD
  command git pull -q origin HEAD
else
  cd "$ZI_HOME" || return
  printf '%s\n' "[1;34m▓▒░[0m Installing [1;36m(z-shell/zi)[1;33m plugin manager[0m at [1;35m${ZI_HOME}/${ZI_BIN_DIR_NAME}[0m"
  { git clone --progress --depth=1 --branch "$BOPT" https://github.com/z-shell/zi.git "$ZI_BIN_DIR_NAME" \
    2>&1 | { /tmp/zi/git-process-output.zsh || cat; }; } 2>/dev/null
  if [ -d "$ZI_BIN_DIR_NAME" ]; then
    printf '%s\n' "[1;34m▓▒░[0m Successfully installed at [1;32m${ZI_HOME}/${ZI_BIN_DIR_NAME}[0m".
  else
    printf '%s\n' "[1;31m▓▒░[0m Something went wrong, couldn't install ZI at [1;33m${ZI_HOME}/${ZI_BIN_DIR_NAME}[0m"
  fi
fi

#
# Modify .zshrc
#

MAIN_PROFILE() {
  THE_ZDOTDIR="${ZDOTDIR:-$HOME}"
  if grep -E '(zi|init|zinit)\.zsh' "${THE_ZDOTDIR}/.zshrc" >/dev/null 2>&1; then
    printf '%s\n' "[34m▓▒░[34m Seems that .zshrc already has content or setup skipped - no changes will be made."
    ZOPT='skip'
  fi
  if [ "$ZOPT" != skip ]; then
    printf '%s\n' "[34m▓▒░[0m Updating ${THE_ZDOTDIR}/.zshrc"
    ZI_HOME="$(echo "$ZI_HOME" | sed "s|$HOME|\$HOME|")"
    command cat <<-EOF >>"${THE_ZDOTDIR}/.zshrc"
if [[ ! -f ${ZI_HOME}/${ZI_BIN_DIR_NAME}/zi.zsh ]]; then
  print -P "%F{33}▓▒░ %F{160}Installing (%F{33}z-shell/zi%F{160})…%f"
  command mkdir -p "$ZI_HOME" && command chmod g-rwX "$ZI_HOME"
  command git clone -q --depth=1 --branch "$BOPT" https://github.com/z-shell/zi "${ZI_HOME}/${ZI_BIN_DIR_NAME}" && \\
    print -P "%F{33}▓▒░ %F{34}Installation successful.%f%b" || \\
    print -P "%F{160}▓▒░ The clone has failed.%f%b"
fi
source "${ZI_HOME}/${ZI_BIN_DIR_NAME}/zi.zsh"
autoload -Uz _zi
(( \${+_comps} )) && _comps[zi]=_zi
# examples here -> https://z-shell.pages.dev/docs/gallery/collection
zicompinit # <- https://z-shell.pages.dev/docs/gallery/collection#minimal
EOF
    printf '%s\n' "[34m▓▒░[0m[1;36m Minimal configuration[0m"
  fi
  if [ "$AOPT" = loader ] && [ "$ZOPT" != skip ]; then
    command rm -rf "${THE_ZDOTDIR}/.zshrc"
    command cat <<-EOF >>"${THE_ZDOTDIR}/.zshrc"
if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/zi/init.zsh" ]]; then
  source "${XDG_CONFIG_HOME:-$HOME/.config}/zi/init.zsh" && zzinit
fi
EOF
    printf '%s\n' "[34m▓▒░[0m[1;36m Loader added[0m"
  fi
}

ANNEX_PROFILE() {
  if [ "$AOPT" = annex ]; then
    file="${WORKDIR}/temp-zsh-config"
    command cat <<-EOF >>"$file"
zi light-mode for \\
  z-shell/z-a-meta-plugins \\
  @annexes # <- https://z-shell.pages.dev/docs/ecosystem/annexes
# examples here -> https://z-shell.pages.dev/docs/gallery/collection
zicompinit # <- https://z-shell.pages.dev/docs/gallery/collection#minimal
EOF
    printf '%s\n' "[34m▓▒░[0m[1;36m Installing annexes[0m"
    command cat "$file" >>"${THE_ZDOTDIR}/.zshrc"
    zsh -ic "@zi-scheduler burst"
  elif [ "$AOPT" = zunit ]; then
    file2="${WORKDIR}/temp-zunit-config"
    command cat <<-EOF >>"$file2"
zi light-mode for \\
  z-shell/z-a-meta-plugins \\
  @annexes @molovo
EOF
    printf '%s\n' "[34m▓▒░[0m[1;36m Installing annexes + zunit[0m"
    command cat "$file2" >>"${THE_ZDOTDIR}/.zshrc"
    zsh -ic "@zi-scheduler burst"
  else
    printf '%s\n' "[34m▓▒░[0m[1;36m Skipped all annexes[0m"
  fi
}

CLOSE_PROFILE() {
  git_refs="$(command cd "${ZI_HOME}/${ZI_BIN_DIR_NAME}" || true; command git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit | head -10)"
  printf '%s\n' "[34m▓▒░[0m[38;5;226m Latest changes:[0m"
  printf '%s\n' "$git_refs"
  command cat <<-EOF
[34m▓▒░[0m[1;36m Successfully installed![0m
[34m▓▒░[0m[38;5;226m Wiki:         https://z-shell.pages.dev[0m
[34m▓▒░[0m[38;5;226m Issues:       https://github.com/z-shell/zi/issues[0m
[34m▓▒░[0m[38;5;226m Discussions:  https://github.com/z-shell/zi/discussions[0m
EOF
}

MAIN() {
  MAIN_PROFILE
  ANNEX_PROFILE
  CLOSE_PROFILE
  exit 0
}

while true; do
  MAIN "${@}"
done
