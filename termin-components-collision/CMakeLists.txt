cmake_minimum_required(VERSION 3.16)
project(termin_components_collision LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(termin_base REQUIRED)
find_package(termin_scene REQUIRED)
find_package(termin_inspect REQUIRED)
find_package(termin_mesh REQUIRED)
find_package(termin_collision REQUIRED)

include(${CMAKE_CURRENT_LIST_DIR}/../termin-modules/cmake/TerminModule.cmake)

termin_add_module(
    NAME termin_components_collision
    NAMESPACE termin_components_collision::
    SOURCES components/collider_component.cpp
    PUBLIC_DEPS tcbase::termin_base termin_scene::termin_scene termin_inspect::termin_inspect tmesh::termin_mesh termin_collision::termin_collision
    FIND_DEPS termin_base termin_scene termin_inspect termin_mesh termin_collision
    INSTALL_HEADERS components
)
