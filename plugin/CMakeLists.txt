cmake_minimum_required(VERSION 3.19)

project(mugen-audio VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 6.9 REQUIRED COMPONENTS Qml)
find_package(PkgConfig REQUIRED)
find_package(Threads REQUIRED)
pkg_check_modules(Cava IMPORTED_TARGET libcava REQUIRED)

qt_standard_project_setup(REQUIRES 6.9)

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")

qt_add_qml_module(mugen-audio
    URI Mugen.Audio
    VERSION 1.0
    SOURCES
        src/cavasource.cpp
        src/cavasource.hpp
)

# The generated type registration includes headers by bare basename.
target_include_directories(mugen-audio PRIVATE src)

target_link_libraries(mugen-audio PRIVATE Qt6::Qml PkgConfig::Cava Threads::Threads)

include(GNUInstallDirs)

set(MUGEN_AUDIO_QMLDIR "${CMAKE_INSTALL_LIBDIR}/qt-6/qml/Mugen/Audio")

# nixpkgs rejects a result whose rpath still points into the sandbox build dir.
set_target_properties(mugen-audioplugin PROPERTIES
    INSTALL_RPATH "$ORIGIN"
    BUILD_WITH_INSTALL_RPATH TRUE
)

install(TARGETS mugen-audio
    LIBRARY DESTINATION "${MUGEN_AUDIO_QMLDIR}"
)
install(DIRECTORY "${QT_QML_OUTPUT_DIRECTORY}/Mugen"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt-6/qml"
)
