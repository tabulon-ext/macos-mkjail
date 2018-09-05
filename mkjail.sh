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
DYLIBS_TO_COPY=("libncurses.5.4.dylib" "libSystem.B.dylib" "libiconv.2.dylib" "libc++.1.dylib" "libobjc.A.dylib" "libc++abi.dylib" "closure/libclosured.dylib")
SCRIPT_DEPENDS=("sudo" "tar" "curl")
COMMANDS_TO_CHECK=("cc -v" "make -v" "gcc -v" "xcode-select -p")

# No jail_name given, print usage and exit
if [[ -z "$1" ]]; then
  echo "Usage: mkjail.sh <jail_name>"
  echo "This script creates a new macOS jail inside jail_name with GNU bash, coreutils and inetutils."
  exit 0
fi

if [[ "$EUID" == 0 ]]; then
  echo "Do not run this tool as root, this will cause homebrew to not work."
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
echo "Checking for command line tools..."
for cmd_to_check in "${COMMANDS_TO_CHECK[@]}"
do
  ${cmd_to_check} &> /dev/null
  CMD_EXIT_CODE=$?
  if [[ ${CMD_EXIT_CODE} != 0 ]]; then
    # echo "DEBUG: Command: \"${cmd_to_check}\", exit code ${CMD_EXIT_CODE}"
    echo "E: Xcode command line tools aren't installed. Run this script after installing them."
    xcode-select --install
    exit 1
  fi
done


# Make temporary directory for this script
rm -rf '.tmpmkjailsh10'
mkdir '.tmpmkjailsh10'
if [[ $? != 0 ]]; then error_exit "E: Unable to create temporary directory."; fi
TEMP_DIR="$(absolute_path ".tmpmkjailsh10")"
cd '.tmpmkjailsh10'

# Create the chroot folder
# echo "DEBUG: \"${CHROOT_PATH}\""
mkdir "${CHROOT_PATH}"

# Download the source code tarballs for the following utilities:
# GNU bash
# GNU coreutils
# GNU inetutils
sh -c "set -e;\
cd \"$(pwd -P)\";\
curl \"https://ftp.gnu.org/pub/gnu/coreutils/coreutils-8.30.tar.xz\" --output coreutils.tar.xz; \
curl \"https://ftp.gnu.org/pub/gnu/bash/bash-4.4.18.tar.gz\" --output bash.tar.gz; \
curl \"https://ftp.gnu.org/pub/gnu/inetutils/inetutils-1.9.4.tar.xz\" --output inetutils.tar.xz;"
if [[ $? != 0 ]]; then error_exit "E: Unable to download the source code tarballs from GNU FTP."; fi

# Extract the tarballs
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

# Build Bash
echo "Building GNU Bash..."
cd bash_build
echo "\$ ../bash_src/configure --prefix=\"${CHROOT_PATH}\""
../bash_src/configure --prefix="${CHROOT_PATH}"
if [[ $? != 0 ]]; then error_exit "E: configure script for bash failed."; fi
make -j4
if [[ $? != 0 ]]; then error_exit "E: Unable to build bash from source."; fi
echo "Bash has been built succesfully. Building GNU coreutils..."

# Build coreutils
cd ../coreutils_build
../coreutils_src/configure --prefix="${CHROOT_PATH}"
if [[ $? != 0 ]]; then error_exit "E: configure script for coreutils failed."; fi
make -j4
if [[ $? != 0 ]]; then error_exit "E: Unable to build coreutils from source."; fi
echo "Coreutils has been built succesfully. Building GNU inetutils..."

# Build inetutils
cd ../inetutils_build
sh -c "set -e;\
echo $(pwd -P);\
../inetutils_src/configure --prefix=\"${CHROOT_PATH}\";\
make -j4;"
if [[ $? != 0 ]]; then
  echo "W: Unable to build inetutils from source. The script will continue anyway."
fi

set -e
pushd "${CHROOT_PATH}"
  echo "Creating chroot tree..."
  mkdir Applications bin dev etc sbin tmp Users usr var include lib share libexec System Library
  mkdir Applications/Utilities Users/Shared usr/bin usr/include usr/lib usr/libexec usr/local usr/sbin usr/share var/db var/folders var/root var/run var/tmp System/Library
  mkdir System/Library/Frameworks System/Library/PrivateFrameworks usr/lib/closure usr/lib/system
  mkdir "Users/$(whoami)"
  echo "Adding dyld..."
  cp /usr/lib/dyld usr/lib/dyld
  echo "Installing bash and coreutils..."
popd
cd ../bash_build
make install
cd ../coreutils_build
make install
cd ../inetutils_build
make install || true
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
echo "Cleaning up..."
cd "${CHROOT_PATH}"
rm -vrf "${TEMP_DIR}" || true
echo "The jail was created succesfully. To chroot into the created directory, run the following command:\n\$ sudo chroot -u $(whoami) \"${CHROOT_PATH}\" /bin/bash"