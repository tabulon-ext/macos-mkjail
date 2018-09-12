#!/usr/bin/env bash

if [[ "${OSTYPE}" != darwin* ]]; then echo "This script is only for macOS."; exit 5; fi

OWNER_UID="$EUID"
OWNER_NAME="$(whoami)"

absolute_path() {
  pushd "$1" &> /dev/null || return 1
  pwd -P
  PWD_EXIT_CODE=$?
  popd &> /dev/null
  return ${PWD_EXIT_CODE}
}

error_exit() {
  echo "$1"
  exit 1
}

# Everything inside /usr/lib/system will be copied as well.
DYLIBS_TO_COPY=("libncurses.5.4.dylib" "libSystem.B.dylib" "libiconv.2.dylib" "libc++.1.dylib" "libobjc.A.dylib" "libc++abi.dylib" "closure/libclosured.dylib" "libutil.dylib" "libz.1.dylib" "libedit.3.dylib")
OTHER_FILES_TO_COPY=("/etc/protocols" "/etc/hosts")
SCRIPT_DEPENDS=("sudo" "tar" "curl" "git")
COMMANDS_TO_CHECK=("cc -v" "make -v" "gcc -v" "xcode-select -p")
THING_LINKS=(
  "https://ftp.gnu.org/pub/gnu/bash/bash-4.4.18.tar.gz"
  "https://ftp.gnu.org/pub/gnu/inetutils/inetutils-1.9.4.tar.xz"
  "https://ftp.gnu.org/pub/gnu/coreutils/coreutils-8.30.tar.xz"
)
THINGS_TO_BUILD=("bash" "inetutils" "coreutils")
OPTIONAL=(0 1 0)
MAKE_ARGS=""

# BEGIN - Modify these values to support more stuff #
EXTRA_LINKS=(
  "https://ftp.gnu.org/pub/gnu/nano/nano-2.9.8.tar.xz"
  "https://ftp.gnu.org/pub/gnu/less/less-530.tar.gz"
  "https://ftp.gnu.org/pub/gnu/make/make-4.2.1.tar.gz"
  "https://ftp.gnu.org/pub/gnu/grep/grep-3.1.tar.xz"
  "https://ftp.gnu.org/pub/gnu/gzip/gzip-1.9.tar.xz"
  "https://netcologne.dl.sourceforge.net/project/zsh/zsh/5.5.1/zsh-5.5.1.tar.xz"
  "https://ftp.gnu.org/pub/gnu/tar/tar-1.30.tar.xz"
  "https://ftp.gnu.org/pub/gnu/binutils/binutils-2.31.1.tar.xz"
  "https://datapacket.dl.sourceforge.net/project/lzmautils/xz-5.2.4.tar.xz"
  "https://raw.githubusercontent.com/pixelomer/utility-archive/master/curl-nofw.tar"
)
EXTRAS_TO_BUILD=("nano" "less" "make" "grep" "gzip" "zsh" "tar" "binutils" "xz-utils" "curl")
INSTALL_EXTRAS_TO="/usr"

EXTRA_LINK_TYPE=(0 1 1 0 0 0 0 0 0 3)
# 0: tar.xz archive
# 1: tar.gz archive
# 2: Git (bootstrap.sh) # NOT IMPLEMENTED
# 3: tar archive with precompiled binaries

STATE=(0 0 0 0 0 3 0 0 0 0)
# 0: Runs fine
# 1: Doesn't start/unusable
# 2: Runs fine, some features not available
# 3: Starts/runs, not fully tested
# 4: Starts, some core features unavailable

EXTRAS=(0 0 0 0 0 0 0 0 0 1)
# 0: Extra (not installed by default)
# 1: Recommended (installed by default)

# END #

EXTRAS_AVAILABLE=0

MANAGE_ARG="-m"
EXTRA_UTIL_ARG="-e"
THREADING_ARG="-j"
BASIC_ARG="-b"

# No jail_name given, print usage and exit
if [[ -z "$1" || "$1" == "--help" || "$1" == "-h" ]]; then
  cat <<EOF
Usage: $0 [${MANAGE_ARG}] <jail_name> [${EXTRA_UTIL_ARG} <util1> [util2]...] [${THREADING_ARG} <threads>]
This script creates a new macOS chroot jail inside jail_name with GNU utilities.
  
${MANAGE_ARG}: Opens up a basic prompt to modify the chroot. Requires the chroot to be created with this utility.
${EXTRA_UTIL_ARG}: Extra utilities to build and install. Run this script only with this argument to list the supported utilities. Not required if you specify ${MANAGE_ARG}
${THREADING_ARG}: Use this to specify how much threads to use during compilation.
${BASIC_ARG}: Install only required utilities and don't install recommended utilities.

Dont use ${EXTRA_UTIL_ARG} and ${BASIC_ARG} together, only the first one will take effect.
EOF
  exit 0
elif [[ "$1" == "${EXTRA_UTIL_ARG}" ]]; then
  echo "Supported utilities:"
  n=0
  for util in "${EXTRAS_TO_BUILD[@]}"; do
    NS=""
    if [[ ${STATE[${n}]} == 1 ]]; then NS=" (does not work)"
    elif [[ ${STATE[${n}]} == 2 ]]; then NS=" (not fully functional)"
    elif [[ ${STATE[${n}]} == 3 ]]; then NS=" (seems to work, not fully tested)"
    elif [[ ${STATE[${n}]} == 4 ]]; then NS=" (some core features unavailable)"; fi
    echo "- ${util}${NS}"
    ((n++))
  done
  echo "Use \"all\" to install every supported extra utility."
  exit 0
fi

# Check if the user is root. Compiling as root can be dangerous and chroot permissions will be broken as well.
if [[ "$EUID" == 0 ]]; then
  echo "Do not run this tool as root, building as root can cause problems."
  exit 1
fi

# Start the manager
if [[ "$1" == "${MANAGE_ARG}" && ! -z "$2" ]]; then
  CHROOT_PATH="$(absolute_path "$2")" || error_exit "Unable to get absolute path for the chroot jail."
  while true; do
    read -p "mkjail> " answer
    answ_array=(${answer}) # TODO: Find a better way to split by space.
    case "${answ_array[0]}" in
      exit) break ;;
      help)
        cat <<EOF
exit - Leave jail manager.
fixperms - Sets the right permissions for the chroot jail.
breakperms - TESTING PURPOSES ONLY.
pwd - Prints the currently selected jail.
util - Utility manager command.
clear - Clears the terminal.
EOF
        ;;
      fixperms)
        echo "Setting permissions. You might be asked for your password."
        sh <<EOC
          set -x -e
          sudo chown -R 0:0 "${CHROOT_PATH}"
          sudo chown -R ${OWNER_UID}:20 "${CHROOT_PATH}/Users/${OWNER_NAME}"
          sudo chmod u+s "${CHROOT_PATH}/bin/ping"
          exit &> /dev/null
EOC
        exitcode="$?"
        if [[ "${exitcode}" != 0 ]]; then
          echo "Unable to set permissions: ${exitcode}";
        fi ;;
      breakperms)
        echo "Breaking permissions. You might be asked for your password."
        sh <<EOC
          set -x -e
          sudo chown -R 0:0 "${CHROOT_PATH}"
          sudo chown -R ${OWNER_UID}:20 "${CHROOT_PATH}/"*
          exit &> /dev/null
EOC
        exitcode="$?"
        if [[ "${exitcode}" != 0 ]]; then
          echo "Unable to break permissions: ${exitcode}";
        fi ;;
      pwd) echo "${CHROOT_PATH}" ;;
      clear) clear ;;
      util)
        if [[ -z "${answ_array[1]}" ]]; then cat <<EOF
Usage: util <action>
Extra utility manager actions:
- list: Lists available extra utilities
- install: Installs new utilities
EOF
        else
          if [[ ${answ_array[1]} == "list" ]]; then
            for util in "${EXTRAS_TO_BUILD[@]}"; do
              echo "- ${util}"
              ((n++))
            done
          else echo "util: ${answ_array[1]}: unknown action"; fi
        fi ;;
      *)
        if [[ ! -z "${answer// }" ]]; then
          echo "$0: ${answer}: command not found"
        fi ;;
    esac
  done
  exit 0
elif [[ "$1" == "${MANAGE_ARG}" && -z "$2" ]]; then
  error_exit "No jail_name given."
fi

absolute_path "$1"
if [[ $? != 0 ]]; then
  echo "Creating a new folder at $1"
  mkdir "$1" &> /dev/null || error_exit "Unable to create $1"
  absolute_path "$1" || error_exit "Unable to get absolute path for $1"
else error_exit "Refusing to turn an existing directory into a chroot jail."; fi

echo "Removing the newly created folder..."
CHROOT_PATH="$(absolute_path "$1")"
rm -rf "${CHROOT_PATH}"

# Check for dependencies
for dependency in "${SCRIPT_DEPENDS[@]}"
do
  printf "${dependency}... "
  type "${dependency}" &> /dev/null
  if [[ $? != 0 ]]; then
    printf "not available\n"
    error_exit "E: ${dependency} is required for this script."
  else printf "$(type -P ${dependency})\n"
  fi
done
printf "brew... "
type "brew" &> /dev/null
if [[ $? == 0 ]]; then
  printf "$(type -P brew)\nW: Extra libraries that are installed with homebrew can cause the programs installed inside the jail to not start.\n"
else printf "not available (this is good)\n"
fi

# Check for xcode command line tools by running a few commands
printf "Checking for command line tools... "
for cmd_to_check in "${COMMANDS_TO_CHECK[@]}"
do
  ${cmd_to_check} &> /dev/null
  CMD_EXIT_CODE=$?
  if [[ ${CMD_EXIT_CODE} != 0 ]]; then
    printf "not installed\n"
    echo "E: Xcode command line tools aren't installed. Run this script after installing them."
    xcode-select --install
    exit 1
  fi
done
printf "installed\n"

# Check for extra utilities
j=0
ttb=0
if [[ "$2" == "${EXTRA_UTIL_ARG}" ]]; then
  for param in "$@"
  do
    if [[ ${param} == "${EXTRA_UTIL_ARG}" && ${j} == 0 ]]; then j=1;
    elif [[ ${j} == 1 ]]; then
      k=0
      for extra_util in "${EXTRAS_TO_BUILD[@]}"
      do
        if [[ "${extra_util}" == "${param}" ]]; then
          EXTRAS[${k}]=1
          EXTRAS_AVAILABLE=1
        elif [[ "${param}" == "all" ]]; then
          echo "Selecting every extra utility"
          v=0
          EXTRAS_AVAILABLE=1
          for unused_var in "${EXTRAS_TO_BUILD[@]}"
          do
            EXTRAS[${v}]=1
            ((v++))
          done
          break
        elif [[ "${param}" == "${THREADING_ARG}" ]]; then ttb=1; break; fi
        ((k++))
      done
      if [[ "${ttb}" == 1 ]]; then break;
      elif [[ ${EXTRAS_AVAILABLE} == 0 ]]; then
        error_exit "Unknown utility: ${param}"
      fi
    fi
  done
elif [[ "$2" == "${BASIC_ARG}" ]]; then
  for unusedvar in "${EXTRAS_TO_BUILD[@]}"
  do
    EXTRAS[${j}]=0
    ((j++))
  done
fi

if [[ "${#@}" -gt 2 ]]; then
  last_two_args=("${@: -2:1}" "${@: -1}")
  # Check if threading argument is passed and if the next argument is an integer
  if [[ "${last_two_args[0]}" == "-j" ]] && [ "${last_two_args[1]}" -eq "${last_two_args[1]}" ]; then
    MAKE_ARGS="${MAKE_ARGS} -j${last_two_args[1]}"
    echo "${last_two_args[1]} threads will be used."
  fi
fi

# Make temporary directory for this script
rm -rf '.tmpmkjailsh10'
mkdir '.tmpmkjailsh10' || error_exit "E: Unable to create temporary directory."
TEMP_DIR="$(absolute_path ".tmpmkjailsh10")"
cd '.tmpmkjailsh10'

# Download the source code tarballs for the following utilities:
# GNU bash
# GNU coreutils
# GNU inetutils
cd "${TEMP_DIR}"
sh -c "set -e;\
cd \"$(pwd -P)\";\
curl \"${THING_LINKS[2]}\" --output coreutils.tar.xz; \
curl \"${THING_LINKS[0]}\" --output bash.tar.gz; \
curl \"${THING_LINKS[1]}\" --output inetutils.tar.xz;" || error_exit "E: Unable to download the source code tarballs from GNU FTP."

# Create the chroot jail
mkdir "${CHROOT_PATH}"

# Create the chroot tree
pushd "${CHROOT_PATH}"
  echo "Creating chroot tree..."
  mkdir Applications bin dev etc sbin tmp Users usr var include lib share libexec System Library
  mkdir Applications/Utilities Users/Shared usr/bin usr/include usr/lib usr/libexec usr/local usr/sbin usr/share var/db var/folders var/root var/run var/tmp System/Library
  mkdir System/Library/Frameworks System/Library/PrivateFrameworks usr/lib/closure usr/lib/system usr/local/opt
  mkdir "Users/$(whoami)"
  echo "Adding dyld..."
  cp /usr/lib/dyld usr/lib/dyld
popd

# Download the extras and build them.
cd "${TEMP_DIR}"
if [[ ${EXTRAS_AVAILABLE} == 1 ]]; then
  j=0
  for util_name in "${EXTRAS_TO_BUILD[@]}"
  do
    if [[ ${EXTRAS[${j}]} == 1 ]]; then
      echo "Downloading ${util_name}..."
      extension=".tar.xz"
      tar_arg="-xf"
      if [[ ${EXTRA_LINK_TYPE[${j}]} == 1 ]]; then
        extension=".tar.gz"
        tar_arg="-xzf"
      fi
      if [[ ${EXTRA_LINK_TYPE[${j}]} == 2 ]]; then
        error_exit "E: Git functionality not implemented. Unable to compile ${util_name}.";
      elif [[ ${EXTRA_LINK_TYPE[${j}]} == 3 ]]; then
        sh -c "set -e; \
cd \"$(pwd -P)\"; \
curl \"${EXTRA_LINKS[${j}]}\" --output \"${util_name}.tar\"; " || error_exit "E: Unable to download ${util_name}."
      else
        sh -c "set -e; \
cd \"$(pwd -P)\"; \
curl \"${EXTRA_LINKS[${j}]}\" --output \"${util_name}${extension}\"; \
tar ${tar_arg} \"${util_name}${extension}\"; \
mv \"${util_name}-\"* \"${util_name}_src\"; \
mkdir \"${util_name}_build\"; \
cd \"${util_name}_build\"; \
\"../${util_name}_src/configure\" --prefix=\"${CHROOT_PATH}${INSTALL_EXTRAS_TO}\"; \
make${MAKE_ARGS};" || error_exit "E: Unable to compile ${util_name}."
      fi
    fi
    ((j++))
  done
fi

# Extract the tarballs
cd "${TEMP_DIR}"
echo "Extracting the source code files..."
mkdir bash_build coreutils_build inetutils_build
sh -c "set -e;\
cd \"$(pwd -P)\";\
tar -xzf bash.tar.gz;\
tar -xf coreutils.tar.xz;\
tar -xf inetutils.tar.xz;" || error_exit "E: Unable to extract the tarballs."
mv bash-4.4.18 bash_src
mv inetutils-1.9.4 inetutils_src
mv coreutils-8.30 coreutils_src

j=0
for thing in "${THINGS_TO_BUILD[@]}"
do
  echo "Building ${thing}..."
  sh -c "set -e; \
cd \"$(pwd -P)\"; \
cd \"${thing}_build\"; \
\"../${thing}_src/configure\" --prefix=\"${CHROOT_PATH}\"; \
make${MAKE_ARGS};"
  if [[ $? != 0 ]]; then
    if [[ ${OPTIONAL[${j}]} == 1 ]]; then
      echo "W: Couldn't build ${thing}. Continuing anyway."
    else
      error_exit "E: Unable to build ${thing}, but it is required. Exiting."
    fi
  fi
  ((j++))
done

set -e
echo "Installing utilities..."

j=0
for thing in "${THINGS_TO_BUILD[@]}"
do
  echo "Installing ${thing} inside the chroot jail..."
  OLD_WD="$(pwd -P)"
  cd "${TEMP_DIR}/${thing}_build" || true
  if [[ OLD_WD != "$(pwd -P)" ]]; then
    if [[ ${OPTIONAL[${j}]} == 1 ]]; then
      make install || true
    else
      make install
    fi
  else
    echo "E: Unable to change directory, please report this."
    echo "I: Unable to access \${TEMP_DIR}/${thing}_build"
    exit 1
  fi
  ((j++))
done

cd "${TEMP_DIR}"
if [[ ${EXTRAS_AVAILABLE} == 1 ]]; then
  j=0
  for util_name in "${EXTRAS_TO_BUILD[@]}"
  do
    if [[ ${EXTRAS[${j}]} == 1 && ${EXTRA_LINK_TYPE[${j}]} != 3 ]]; then
      echo "Installing ${util_name} inside the chroot jail..."
      sh -c "set -e; \
cd \"$(pwd -P)\"; \
cd \"${util_name}_build\"; \
make install;" || error_exit "E: Unable to install ${util_name}."
    elif [[ ${EXTRAS[${j}]} == 1 && ${EXTRA_LINK_TYPE[${j}]} == 3 ]]; then
      echo "Unpacking ${util_name} to chroot jail..."
      sh -c "set -e; \
cd \"$(pwd -P)\"; \
tar -xvf \"${util_name}.tar\" -C \"${CHROOT_PATH}\"; " || error_exit "E: Unable to install ${util_name}."
      if [[ ${j} == 9 ]]; then # Special case for cURL
        cp -r "/System/Library/Frameworks/CoreFoundation.framework" "${CHROOT_PATH}/System/Library/Frameworks/CoreFoundation.framework"
      fi
    fi
    ((j++))
  done
fi

echo "Copying libraries..."
for curr_lib in "${DYLIBS_TO_COPY[@]}"
do
  cp "/usr/lib/${curr_lib}" "${CHROOT_PATH}/usr/lib/${curr_lib}"
done
for file in "${OTHER_FILES_TO_COPY[@]}"
do
  cp "${file}" "${CHROOT_PATH}${file}" || true
done

# This folder is needed for the programs to get information about the terminal, and fixes a few programs.
echo "Copying terminfo folder..."
cp -r "/usr/share/terminfo" "${CHROOT_PATH}/usr/share/terminfo"

# Copy every file (not folders) inside /usr/lib/system to the chroot jail
cp /usr/lib/system/* "${CHROOT_PATH}/usr/lib/system/" || true

echo "Setting permissions. You may be asked for your password."

# Start a new shell as root to avoid asking for password multiple times on some systems.
sudo bash <<EOC
chown -R 0:0 "${CHROOT_PATH}"
chown -R ${OWNER_UID}:20 "${CHROOT_PATH}/Users/${OWNER_NAME}"
chmod u+s "${CHROOT_PATH}/bin/ping" || true
chroot -u 0 "${CHROOT_PATH}" "/bin/ln" -s "/bin/bash" "/bin/sh" || true
chroot -u 0 "${CHROOT_PATH}" "/bin/ln" -s "/bin/env" "/usr/bin/env" || true
chroot -u 0 "${CHROOT_PATH}" "/bin/ln" -s "/bin/install" "/usr/bin/install" || true
EOC

echo "Cleaning up..."
cd "${CHROOT_PATH}"
rm -vrf "${TEMP_DIR}" || true
echo "The jail was created succesfully. To chroot into the created directory, run the following command:"
echo "\$ sudo chroot -u $(whoami) \"${CHROOT_PATH}\" /bin/bash"
