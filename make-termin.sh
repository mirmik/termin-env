#!/bin/bash
# Build and install all termin libraries in dependency order:
#   termin-base -> termin-graphics -> termin-gui -> termin
#
# Usage:
#   ./make-termin.sh              # Release build
#   ./make-termin.sh --debug      # Debug build
#   ./make-termin.sh --clean      # Clean before build
#   ./make-termin.sh --only=base  # Build only termin-base
#   ./make-termin.sh --only=gfx   # Build only termin-graphics
#   ./make-termin.sh --only=app   # Build only termin
#   ./make-termin.sh --from=gfx   # Start from termin-graphics (skip base)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUILD_TYPE="Release"
CLEAN=0
ONLY=""
FROM=""

for arg in "$@"; do
    case "$arg" in
        --debug|-d)    BUILD_TYPE="Debug" ;;
        --clean|-c)    CLEAN=1 ;;
        --only=base)   ONLY="base" ;;
        --only=gfx)    ONLY="gfx" ;;
        --only=gui)    ONLY="gui" ;;
        --only=app)    ONLY="app" ;;
        --from=base)   FROM="base" ;;
        --from=gfx)    FROM="gfx" ;;
        --from=gui)    FROM="gui" ;;
        --from=app)    FROM="app" ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --debug, -d       Debug build"
            echo "  --clean, -c       Clean build directories first"
            echo "  --only=base       Build only termin-base"
            echo "  --only=gfx        Build only termin-graphics"
            echo "  --only=gui        Build only termin-gui"
            echo "  --only=app        Build only termin"
            echo "  --from=base       Build from termin-base onwards (all)"
            echo "  --from=gfx        Build from termin-graphics onwards (skip base)"
            echo "  --from=gui        Build from termin-gui onwards (skip base and gfx)"
            echo "  --from=app        Build only termin (skip base, gfx, gui)"
            echo "  --help, -h        Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

INSTALL_ARGS=""
if [[ "$BUILD_TYPE" == "Debug" ]]; then
    INSTALL_ARGS="--debug"
fi

should_build() {
    local name="$1"
    if [[ -n "$ONLY" ]]; then
        [[ "$ONLY" == "$name" ]]
        return
    fi
    if [[ -n "$FROM" ]]; then
        case "$FROM" in
            base) return 0 ;;
            gfx)  [[ "$name" != "base" ]] ;;
            gui)  [[ "$name" == "gui" || "$name" == "app" ]] ;;
            app)  [[ "$name" == "app" ]] ;;
        esac
        return
    fi
    return 0
}

build_cmake_lib() {
    local name="$1"
    local dir="$2"

    echo ""
    echo "========================================"
    echo "  Building $name ($BUILD_TYPE)"
    echo "========================================"
    echo ""

    cd "$dir"

    local build_dir="build/${BUILD_TYPE}"

    if [[ $CLEAN -eq 1 ]]; then
        echo "Cleaning $build_dir..."
        rm -rf "$build_dir"
    fi

    mkdir -p "$build_dir"

    cmake -S . -B "$build_dir" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DCMAKE_INSTALL_PREFIX="/usr/local"

    cmake --build "$build_dir" -j$(nproc)

    (cd "$dir" && ./install.sh $INSTALL_ARGS)

    echo "Installing $name Python package..."
    if [[ "$name" == "termin-graphics" ]]; then
        pip install --no-build-isolation .
    else
        pip install .
    fi

    echo "$name installed to /usr/local"
}

build_termin() {
    echo ""
    echo "========================================"
    echo "  Building termin ($BUILD_TYPE)"
    echo "========================================"
    echo ""

    cd "$SCRIPT_DIR/termin"

    local build_args=""
    [[ "$BUILD_TYPE" == "Debug" ]] && build_args="--debug"
    [[ $CLEAN -eq 1 ]] && build_args="$build_args --clean"

    "$SCRIPT_DIR/termin/build.sh" $build_args

    echo "Installing termin to /opt/termin..."
    sudo "$SCRIPT_DIR/termin/install_system.sh"
}

# Build chain
if should_build "base"; then
    build_cmake_lib "termin-base" "$SCRIPT_DIR/termin-base"
fi

if should_build "gfx"; then
    build_cmake_lib "termin-graphics" "$SCRIPT_DIR/termin-graphics"
fi

if should_build "gui"; then
    echo ""
    echo "========================================"
    echo "  Installing termin-gui (pip)"
    echo "========================================"
    echo ""
    pip install "$SCRIPT_DIR/termin-gui"
fi

if should_build "app"; then
    build_termin
fi

echo ""
echo "========================================"
echo "  All done!"
echo "========================================"
