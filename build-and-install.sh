#!/bin/bash
# Build and install all termin libraries in dependency order:
#   termin-base -> termin-mesh -> termin-graphics -> termin-inspect -> termin-scene -> termin-collision -> termin-gui -> termin
#
# Usage:
#   ./make-termin.sh              # Release build
#   ./make-termin.sh --debug      # Debug build
#   ./make-termin.sh --clean      # Clean before build
#   ./make-termin.sh --only=base  # Build only termin-base
#   ./make-termin.sh --only=scene # Build only termin-scene
#   ./make-termin.sh --only=mesh  # Build only termin-mesh
#   ./make-termin.sh --only=collision # Build only termin-collision
#   ./make-termin.sh --only=gfx   # Build only termin-graphics
#   ./make-termin.sh --only=app   # Build only termin
#   ./make-termin.sh --from=scene # Start from termin-scene (skip base + mesh + gfx)
#   ./make-termin.sh --from=collision # Start from termin-collision
#   ./make-termin.sh --from=mesh # Start from termin-mesh
#   ./make-termin.sh --from=gfx   # Start from termin-graphics (skip base + mesh)
#   ./make-termin.sh --no-parallel  # Disable parallel build jobs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_PREFIX="/opt/termin"

BUILD_TYPE="Release"
CLEAN=0
ONLY=""
FROM=""
NO_PARALLEL=0
BUILD_JOBS="$(nproc)"

for arg in "$@"; do
    case "$arg" in
        --debug|-d)    BUILD_TYPE="Debug" ;;
        --clean|-c)    CLEAN=1 ;;
        --only=base)   ONLY="base" ;;
        --only=mesh)   ONLY="mesh" ;;
        --only=scene)  ONLY="scene" ;;
        --only=collision) ONLY="collision" ;;
        --only=gfx)    ONLY="gfx" ;;
        --only=gui)    ONLY="gui" ;;
        --only=app)    ONLY="app" ;;
        --from=base)   FROM="base" ;;
        --from=mesh)   FROM="mesh" ;;
        --from=scene)  FROM="scene" ;;
        --from=collision) FROM="collision" ;;
        --from=gfx)    FROM="gfx" ;;
        --from=gui)    FROM="gui" ;;
        --from=app)    FROM="app" ;;
        --no-parallel) NO_PARALLEL=1 ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --debug, -d       Debug build"
            echo "  --clean, -c       Clean build directories first"
            echo "  --only=base       Build only termin-base"
            echo "  --only=mesh       Build only termin-mesh"
            echo "  --only=scene      Build only termin-scene"
            echo "  --only=collision  Build only termin-collision"
            echo "  --only=gfx        Build only termin-graphics"
            echo "  --only=gui        Build only termin-gui"
            echo "  --only=app        Build only termin"
            echo "  --from=base       Build from termin-base onwards (all)"
            echo "  --from=mesh       Build from termin-mesh onwards (skip base)"
            echo "  --from=scene      Build from termin-scene onwards (skip base, mesh and gfx)"
            echo "  --from=collision  Build from termin-collision onwards"
            echo "  --from=gfx        Build from termin-graphics onwards (skip base and mesh)"
            echo "  --from=gui        Build from termin-gui onwards (skip base, scene and gfx)"
            echo "  --from=app        Build only termin (skip base, scene, gfx, gui)"
            echo "  --no-parallel     Disable parallel compilation (equivalent to -j1)"
            echo "  --help, -h        Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

if [[ $NO_PARALLEL -eq 1 ]]; then
    BUILD_JOBS=1
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
            mesh) [[ "$name" == "mesh" || "$name" == "gfx" || "$name" == "scene" || "$name" == "collision" || "$name" == "gui" || "$name" == "app" ]] ;;
            gfx)  [[ "$name" == "gfx" || "$name" == "scene" || "$name" == "collision" || "$name" == "gui" || "$name" == "app" ]] ;;
            scene) [[ "$name" == "scene" || "$name" == "collision" || "$name" == "gui" || "$name" == "app" ]] ;;
            collision) [[ "$name" == "collision" || "$name" == "gui" || "$name" == "app" ]] ;;
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

    local py_exec
    py_exec="$(command -v python3 || true)"
    if [[ -z "$py_exec" ]]; then
        py_exec="$(command -v python || true)"
    fi

    local extra_args=()
    if [[ "$name" == "termin-scene" ]]; then
        extra_args+=(-DTERMIN_SCENE_BUILD_PYTHON=ON)
    elif [[ "$name" == "termin-collision" ]]; then
        extra_args+=(-DTERMIN_COLLISION_BUILD_PYTHON=ON)
    fi

    cmake -S . -B "$build_dir" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DCMAKE_INSTALL_PREFIX="$SDK_PREFIX" \
        -DCMAKE_PREFIX_PATH="$SDK_PREFIX" \
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
        -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON \
        -Dtermin_base_DIR="$SDK_PREFIX/lib/cmake/termin_base" \
        -Dtermin_graphics_DIR="$SDK_PREFIX/lib/cmake/termin_graphics" \
        -Dtermin_mesh_DIR="$SDK_PREFIX/lib/cmake/termin_mesh" \
        -Dtermin_inspect_DIR="$SDK_PREFIX/lib/cmake/termin_inspect" \
        -Dtermin_scene_DIR="$SDK_PREFIX/lib/cmake/termin_scene" \
        -DPython_EXECUTABLE="$py_exec" \
        "${extra_args[@]}"

    cmake --build "$build_dir" --parallel "$BUILD_JOBS"
    sudo cmake --install "$build_dir"

    if [[ "$name" == "termin-scene" || "$name" == "termin-collision" ]]; then
        echo "Skipping Python package install for $name"
    else
        echo "Installing $name Python package..."
        if [[ "$name" == "termin-graphics" ]]; then
            pip install --no-build-isolation .
        else
            pip install .
        fi
    fi

    echo "$name installed to ${SDK_PREFIX}"
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

    # Ensure extracted modules are discoverable for find_package(...)
    local cmake_prefix="$SDK_PREFIX"

    if [[ $NO_PARALLEL -eq 1 ]]; then
        CMAKE_BUILD_PARALLEL_LEVEL=1 CMAKE_PREFIX_PATH="$cmake_prefix" \
        CMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
        CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON \
        "$SCRIPT_DIR/termin/build.sh" $build_args
    else
        CMAKE_PREFIX_PATH="$cmake_prefix" \
        CMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
        CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON \
        "$SCRIPT_DIR/termin/build.sh" $build_args
    fi

    echo "Installing termin to ${SDK_PREFIX}..."
    sudo "$SCRIPT_DIR/termin/install_system.sh"
}

build_termin_inspect() {
    echo ""
    echo "========================================"
    echo "  Building termin-inspect ($BUILD_TYPE)"
    echo "========================================"
    echo ""

    cd "$SCRIPT_DIR/termin-inspect"

    local build_dir="build/${BUILD_TYPE}"
    if [[ $CLEAN -eq 1 ]]; then
        echo "Cleaning $build_dir..."
        rm -rf "$build_dir"
    fi

    mkdir -p "$build_dir"

    local py_exec
    py_exec="$(command -v python3 || true)"
    if [[ -z "$py_exec" ]]; then
        py_exec="$(command -v python || true)"
    fi

    cmake -S . -B "$build_dir" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DCMAKE_INSTALL_PREFIX="$SDK_PREFIX" \
        -DCMAKE_PREFIX_PATH="$SDK_PREFIX" \
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
        -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON \
        -Dtermin_base_DIR="$SDK_PREFIX/lib/cmake/termin_base" \
        -DPython_EXECUTABLE="$py_exec" \
        -DTERMIN_INSPECT_BUILD_PYTHON=ON

    cmake --build "$build_dir" --parallel "$BUILD_JOBS"
    sudo cmake --install "$build_dir"

    echo "termin-inspect installed to ${SDK_PREFIX}"
}

# Build chain
if should_build "base"; then
    build_cmake_lib "termin-base" "$SCRIPT_DIR/termin-base"
fi

if should_build "mesh"; then
    build_cmake_lib "termin-mesh" "$SCRIPT_DIR/termin-mesh"
fi

if should_build "gfx"; then
    build_cmake_lib "termin-graphics" "$SCRIPT_DIR/termin-graphics"
fi

if should_build "scene"; then
    build_termin_inspect
    build_cmake_lib "termin-scene" "$SCRIPT_DIR/termin-scene"
fi

if should_build "collision"; then
    build_cmake_lib "termin-collision" "$SCRIPT_DIR/termin-collision"
fi

if should_build "gui"; then
    echo ""
    echo "========================================"
    echo "  Installing termin-gui (pip)"
    echo "========================================"
    echo ""
    pip install "$SCRIPT_DIR/termin-gui"

    echo ""
    echo "========================================"
    echo "  Installing termin-nodegraph (pip)"
    echo "========================================"
    echo ""
    pip install "$SCRIPT_DIR/termin-nodegraph"
fi

if should_build "app"; then
    build_termin
fi

echo ""
echo "========================================"
echo "  All done!"
echo "========================================"
