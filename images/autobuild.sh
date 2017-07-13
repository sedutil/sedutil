#!/bin/bash

ME="$(basename $0)"

function usage() {
    {
        [[ $# -gt 0 ]] && echo "$ME: $*"
        echo "usage: $ME [-h] [-k <keymap>] [<step> ...]"
        echo ""
        echo "Executes the build steps according to <step> arguments."
        echo "   <step>: complete|pbaroot|pba|cli|images|dist"
        echo ""
        echo "Options:"
        echo "   -k <keymap>: build for non-US keyboard, see http://distro.ibiblio.org/tinycorelinux/faq.html#keyboard"
        echo "      Example for German: -k qwertz/de-latin1"
        echo "   -h: print this help message"
        echo ""
        echo "Each build step mentioned in a <step> argument is executed unconditionally."
        echo ""
        echo "Build steps not mentioned in <step> arguments are executed only if their result does not exist yet."
        echo "'complete' will re-build everything from scratch."
        echo ""
        echo "By default, builds support US keyboards only. To rebuild for a different keyboard, use the '-k' option"
        echo "and include build steps 'images' and 'dist'."
    } >&2
    exit 1
}

# Build arguments:

export BUILD_KEYMAP=""

while [[ $# -gt 0 ]] && [[ "$1" =~ ^- ]]; do
    option="$1"
    shift
    case "$option" in
        "-k")
            [[ $# -lt 1 ]] && usage "option \"-k\" requires a keymap argument"
            BUILD_KEYMAP="$1"
            shift
            ;;
        "-h")
            usage
            ;;
        *)
            usage "invalid option \"$option\""
    esac
done

BUILD_STEPS="$*"

# Abort on error
set -e

# Optimal MAKEFLAGS argument if not already defined
if [ -z ${MAKEFLAGS+x} ]; then
    # Add 1 assuming disk IO will block processes from time to time.
    export MAKEFLAGS=$((1 + $(grep processor /proc/cpuinfo | wc -l)))
fi

# Run everything from the path of this script despite how invoked
cd "$( dirname "${BASH_SOURCE[0]}" )"

source conf

if [[ ! -f scratch/setfont.tcz ]]; then
    BUILD_STEPS+=" complete"
else
    [[ -d scratch/buildroot/PBA64 ]] || BUILD_STEPS+=" pbaroot"
    [[ -f ../LinuxPBA/dist/Release_x86_64/GNU-Linux/linuxpba ]] || BUILD_STEPS+=" pba"
    [[ -f ../linux/CLI/dist/Release_x86_64/GNU-Linux/sedutil-cli ]] || BUILD_STEPS+=" cli"
    [[ -f $(echo UEFI64_Release/UEFI64_Release-*.img.gz) ]] || BUILD_STEPS+=" images"
    [[ -f ../dist/sedutil-cli ]] || BUILD_STEPS+=" dist"
fi

echo -e "\n*** $0 starting, build steps: ${BUILD_STEPS:-(none)}, keymap: ${BUILD_KEYMAP:-(default)} ***"

case "$BUILD_STEPS" in
    *complete*)
        echo -e "\n*** Getting resources ***"

        ./getresources
        ;;
esac

case "$BUILD_STEPS" in
    *complete*|*pbaroot*)
        echo -e "\n*** Building PBA root systems ***"

        # Build buildroot before other tools as it provides the toolchain for linuxpba
        # and sedutil-cli.
        ./buildpbaroot
        ;;
esac

case "$BUILD_STEPS" in
    *complete*|*pba*)
        echo -e "\n*** Building PBA executables ***"

        pushd ../LinuxPBA
        rm -rf dist build
        make CONF=Debug
        make CONF=Debug_x86_64
        make CONF=Release
        make CONF=Release_x86_64
        popd
        ;;
esac

case "$BUILD_STEPS" in
    *complete*|*cli*)
        echo -e "\n*** Building CLI executables ***"

        pushd ../linux/CLI
        rm -rf dist build
        make CONF=Debug_i686
        make CONF=Debug_x86_64
        make CONF=Release_i686
        make CONF=Release_x86_64
        popd
        ;;
esac

case "$BUILD_STEPS" in
    *complete*|*images*)
        echo -e "\n*** Building images ***"

        # Build BIOS images (untested, probably subtly broken)
        #./buildbiospba Release
        #./buildbiospba Debug

        # Build UEFI images
        ./buildUEFI64 Release
        ./buildUEFI64 Debug

        # Rescue build
        ./buildrescue
        ;;
esac

case "$BUILD_STEPS" in
    *complete*|*dist*)
        echo -e "\n*** Building distribution ***"

        [ -d ../dist ] && rm -rf ../dist
        mkdir -p ../dist/images
        cd ../dist
        for file in ../images/{UEFI64_*,Rescue}/*.img.gz; do
            zcat "$file" > images/"$(basename ${file%.gz})"
        done
        cp ../linux/CLI/dist/Release_x86_64/GNU-Linux/sedutil-cli .

        ls -lR "$(pwd)"
        ;;
esac

echo -e "\n*** Completed ***"
