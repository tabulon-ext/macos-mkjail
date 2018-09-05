#!/usr/bin/env sh

absolute_path() {
  pushd "$1" &> /dev/null
  if [[ $? != 0 ]]; then return 1; fi
  pwd -P
  PWD_EXIT_CODE=$?
  popd &> /dev/null
  return ${PWD_EXIT_CODE}
}

error_exit () {
  echo "$1"
  exit 1
}

# Everything inside /usr/lib/system will be copied as well.
DYLIBS_TO_COPY=("libncurses.5.4.dylib" "libSystem.B.dylib" "libiconv.2.dylib" "libc++.1.dylib" "libobjc.A.dylib" "libc++abi.dylib" "closure/libclosured.dylib" "libutil.dylib" "libz.1.dylib")
SCRIPT_DEPENDS=("sudo" "tar" "curl" "git")
COMMANDS_TO_CHECK=("cc -v" "make -v" "gcc -v" "xcode-select -p")
THING_LINKS=("https://ftp.gnu.org/pub/gnu/bash/bash-4.4.18.tar.gz" "https://ftp.gnu.org/pub/gnu/inetutils/inetutils-1.9.4.tar.xz" "https://ftp.gnu.org/pub/gnu/coreutils/coreutils-8.30.tar.xz")
THINGS_TO_BUILD=("bash" "inetutils" "coreutils")
OPTIONAL=(0 1 0)
# BEGIN - Modify these values to support more stuff
EXTRA_LINKS=("https://ftp.gnu.org/pub/gnu/nano/nano-2.9.8.tar.xz" "https://ftp.gnu.org/pub/gnu/less/less-530.tar.gz" "https://ftp.gnu.org/pub/gnu/make/make-4.2.1.tar.gz" "https://ftp.gnu.org/pub/gnu/grep/grep-3.1.tar.xz" "https://ftp.gnu.org/pub/gnu/gzip/gzip-1.9.tar.xz")
EXTRAS_TO_BUILD=("nano" "less" "make" "grep" "gzip")
EXTRA_LINK_TYPE=(0 1 1 0 0)
MIGHT_NOT_WORK=(1 0 0 0 0)
NOT_FULLY_FUNC=(0 1 0 0 0)
# 0: tar.xz archive
# 1: tar.gz archive
# 2: Git (bootstrap) # NOT IMPLEMENTED
EXTRAS=(0 0 0 0 0)
# END
EXTRAS_AVAILABLE=0

# No jail_name given, print usage and exit
if [[ -z "$1" || "$1" == "--help" || "$1" == "-h" || "$1" == "--extra-utilities" ]]; then
  if [[ "$1" == "--extra-utilities" ]]; then
    echo "Supported utilities:"
    n=0
    for util in "${EXTRAS_TO_BUILD[@]}"; do
      NS=""
      if [[ ${MIGHT_NOT_WORK[${n}]} == 1 ]]; then NS=" (might not work)"
      elif [[ ${NOT_FULLY_FUNC[${n}]} == 1 ]]; then NS=" (not fully functional)"; fi
      echo "- ${util}${NS}"
      ((n++))
    done
    exit 0
  fi
  echo "Usage: $0 <jail_name> [--extra-utilities [utility_1] [utility_2]...]"
  echo "This script creates a new macOS chroot jail inside jail_name with GNU utilities."
  echo "--extra-utilites: Extra utilities to build and install. Run this script only with this argument to list the supported utilities."
  exit 0
fi

if [[ (! -z "$2") && ("$2" != "--extra-utilities") ]]; then
  error_exit "$0: Invalid argument: $2"
fi

if [[ "$EUID" == 0 ]]; then
  echo "Do not run this tool as root, building as root can cause problems."
  exit 1
fi

absolute_path "$1"
if [[ $? != 0 ]]; then
  echo "Creating a new folder in $1"
  mkdir "$1"
  if [[ $? != 0 ]]; then echo "Unable to create $1"; exit 1; fi
  absolute_path "$1"
  if [[ $? != 0 ]]; then echo "Unable to get absolute path for $1"; exit 1; fi
else echo "Refusing to turn an existing directory into a chroot jail."; exit 1; fi

echo "Removing the newly created folder..."
CHROOT_PATH="$(absolute_path "$1")"
rm -rf ${CHROOT_PATH}

# Check for dependencies
for dependency in "${SCRIPT_DEPENDS[@]}"
do
  printf "${dependency}... "
  type "${dependency}" &> /dev/null
  if [[ $? != 0 ]]; then
    printf "not available\n"
    error_exit "E: ${dependency} is required for this script."
  else printf "$(whereis ${dependency})\n"
  fi
done

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
if [[ "$2" == "--extra-utilities" ]]; then
  for param in "$@"
  do
    if [[ ${param} == "--extra-utilities" && ${j} == 0 ]]; then j=1;
    elif [[ ${j} == 1 ]]; then
      k=0
      m=0
      for extra_util in "${EXTRAS_TO_BUILD[@]}"
      do
        if [[ "${extra_util}" == "${param}" ]]; then
          EXTRAS[${k}]=1
          EXTRAS_AVAILABLE=1
          m=1
        fi
        ((k++))
      done
      if [[ $m == 0 ]]; then
        error_exit "Unknown utility: ${param}"
      fi
    fi
  done
fi

# Make temporary directory for this script
rm -rf '.tmpmkjailsh10'
mkdir '.tmpmkjailsh10'
if [[ $? != 0 ]]; then error_exit "E: Unable to create temporary directory."; fi
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
curl \"${THING_LINKS[1]}\" --output inetutils.tar.xz;"
if [[ $? != 0 ]]; then error_exit "E: Unable to download the source code tarballs from GNU FTP."; fi

# Create the chroot jail
mkdir "${CHROOT_PATH}"

# Download the extras and extract them
cd "${TEMP_DIR}"
if [[ ${EXTRAS_AVAILABLE} == 1 ]]; then
  j=0
  for util_name in "${EXTRAS_TO_BUILD[@]}"
  do
    if [[ ${EXTRAS[${j}]} == 1 ]]; then
      echo "Downloading and compiling ${util_name}..."
      extension=".tar.xz"
      tar_arg="-xf"
      if [[ ${EXTRA_LINK_TYPE[${j}]} == 1 ]]; then
        extension=".tar.gz"
        tar_arg="-xzf"
      fi
      if [[ ${EXTRA_LINK_TYPE[${j}]} == 2 ]]; then
        error_exit "E: Git functionality not implemented. Unable to compile ${util_name}.";
      else
        sh -c "set -e; \
cd \"$(pwd -P)\"; \
curl \"${EXTRA_LINKS[${j}]}\" --output \"${util_name}${extension}\"; \
tar ${tar_arg} \"${util_name}${extension}\"; \
mv \"${util_name}-\"* \"${util_name}_src\"; \
mkdir \"${util_name}_build\"; \
cd \"${util_name}_build\"; \
\"../${util_name}_src/configure\" --prefix=\"${CHROOT_PATH}\"; \
make;"
        if [[ $? != 0 ]]; then error_exit "E: Unable to compile ${util_name}."; fi
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
tar -xf inetutils.tar.xz;"
if [[ $? != 0 ]]; then error_exit "E: Unable to extract the tarballs."; fi
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
make;"
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
pushd "${CHROOT_PATH}"
  echo "Creating chroot tree..."
  mkdir Applications bin dev etc sbin tmp Users usr var include lib share libexec System Library
  mkdir Applications/Utilities Users/Shared usr/bin usr/include usr/lib usr/libexec usr/local usr/sbin usr/share var/db var/folders var/root var/run var/tmp System/Library
  mkdir System/Library/Frameworks System/Library/PrivateFrameworks usr/lib/closure usr/lib/system
  mkdir "Users/$(whoami)"
  echo "Adding dyld..."
  cp /usr/lib/dyld usr/lib/dyld
  echo "Installing utilities..."
popd

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
    if [[ ${EXTRAS[${j}]} == 1 ]]; then
      echo "Installing ${util_name} inside the chroot jail..."
      sh -c "set -e; \
cd \"$(pwd -P)\"; \
cd \"${util_name}_build\"; \
make install;"
      if [[ $? != 0 ]]; then error_exit "E: Unable to install ${util_name}."; fi
    fi
    ((j++))
  done
fi

echo "Copying libraries for bash and coreutils..."
for curr_lib in "${DYLIBS_TO_COPY[@]}"
do
  cp "/usr/lib/${curr_lib}" "${CHROOT_PATH}/usr/lib/${curr_lib}"
done
cp /usr/lib/system/* "${CHROOT_PATH}/usr/lib/system/" || true
echo "Setting permissions. You may be asked for your password."
sudo chown -R 0:0 "${CHROOT_PATH}"
OWNER_UID="$EUID"
OWNER_NAME="$(whoami)"
sudo chown -R ${OWNER_UID}:20 "${CHROOT_PATH}/Users/${OWNER_NAME}"
# BEGIN - Attempt to fix internet connection inside chroot jail 
sudo chmod u+s "${CHROOT_PATH}/bin/ping" || true
sudo cp "/etc/resolv.conf" "${CHROOT_PATH}/etc/resolv.conf" || true
sudo cp "/etc/protocols" "${CHROOT_PATH}/etc/protocols" || true
sudo cp "/etc/hosts" "${CHROOT_PATH}/etc/hosts" || true
sudo cp "/var/run/resolv.conf" "${CHROOT_PATH}/var/run/resolv.conf" || true
# END
echo "Cleaning up..."
cd "${CHROOT_PATH}"
rm -vrf "${TEMP_DIR}" || true
echo "The jail was created succesfully. To chroot into the created directory, run the following command:\n\$ sudo chroot -u $(whoami) \"${CHROOT_PATH}\" /bin/bash"