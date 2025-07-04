cmake_minimum_required(VERSION 3.0)

# store the current source directory for future use
set(QT_ANDROID_SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR})

# check the JAVA_HOME environment variable
# (I couldn't find a way to set it from this script, it has to be defined outside)
set(JAVA_HOME $ENV{JAVA_HOME})
if(JAVA_HOME)
    message(STATUS "JAVA_HOME ${JAVA_HOME}")
else()
    message(FATAL_ERROR "The JAVA_HOME environment variable is not set. Please set it to the root directory of the JDK.")
endif()

# make sure that the Android toolchain is used
if(NOT ANDROID)
    message(FATAL_ERROR "Trying to use the CMake Android package without the Android toolchain. Please use the provided toolchain (toolchain/android.toolchain.cmake)")
endif()

# find the Qt root directory
if(NOT Qt${QT_VERSION_MAJOR}Core_DIR)
    find_package(Qt${QT_VERSION_MAJOR}Core REQUIRED)
endif()
set(QT_ANDROID_QT_ROOT ${QTDIR})
message(STATUS "Found Qt for Android: ${QT_ANDROID_QT_ROOT}")

# find the Android SDK
if(NOT QT_ANDROID_SDK_ROOT)
    set(QT_ANDROID_SDK_ROOT $ENV{ANDROID_SDK_ROOT})
    if(NOT QT_ANDROID_SDK_ROOT)
        set(QT_ANDROID_SDK_ROOT ${ANDROID_SDK})
        if(NOT QT_ANDROID_SDK_ROOT)
            set(QT_ANDROID_SDK_ROOT ${ANDROID_SDK_ROOT})
            if(NOT QT_ANDROID_SDK_ROOT)
                message(FATAL_ERROR "Could not find the Android SDK. Please set either the ANDROID_SDK environment variable, or the QT_ANDROID_SDK_ROOT CMake variable to the root directory of the Android SDK")
            endif()
        endif()
    endif()
endif()
string(REPLACE "\\" "/" QT_ANDROID_SDK_ROOT ${QT_ANDROID_SDK_ROOT}) # androiddeployqt doesn't like backslashes in paths
message(STATUS "Found Android SDK: ${QT_ANDROID_SDK_ROOT}")

# find the Android NDK
if(NOT QT_ANDROID_NDK_ROOT)
    set(QT_ANDROID_NDK_ROOT $ENV{ANDROID_NDK})
    if(NOT QT_ANDROID_NDK_ROOT)
        set(QT_ANDROID_NDK_ROOT ${ANDROID_NDK})
        if(NOT QT_ANDROID_NDK_ROOT)
        message(FATAL_ERROR "Could not find the Android NDK. Please set either the ANDROID_NDK environment or CMake variable, or the QT_ANDROID_NDK_ROOT CMake variable to the root directory of the Android NDK")
        endif()
    endif()
endif()
string(REPLACE "\\" "/" QT_ANDROID_NDK_ROOT ${QT_ANDROID_NDK_ROOT}) # androiddeployqt doesn't like backslashes in paths
message(STATUS "Found Android NDK: ${QT_ANDROID_NDK_ROOT}")

include(CMakeParseArguments)

# define a macro to create an Android APK target
#
# example:
# add_qt_android_apk(my_app_apk my_app
#     NAME "My App"
#     JAVA_SOURCES ${CMAKE_CURRENT_LIST_DIR}/java
#     ANDROID_RESOURCES_PATH ${CMAKE_CURRENT_LIST_DIR}/res
#     VERSION_CODE 12
#     QML_ROOT_PATH ${CMAKE_CURRENT_LIST_DIR}/res/qml
#     PACKAGE_NAME "org.mycompany.myapp"
#     PACKAGE_SOURCES ${CMAKE_CURRENT_LIST_DIR}/my-android-sources
#     KEYSTORE ${CMAKE_CURRENT_LIST_DIR}/mykey.keystore myalias
#     KEYSTORE_PASSWORD xxxx
#     KEY_PASSWORD xxxx
#     DEPENDS a_linked_target "path/to/a_linked_library.so" ...
#     INSTALL
#)
#
macro(add_qt_android_apk TARGET SOURCE_TARGET)

    # parse the macro arguments
    cmake_parse_arguments(ARG "INSTALL" "NAME;ICON;SPLASH_SCREEN;QML_ROOT_PATH;VERSION_CODE;ACTIVITY_NAME;PACKAGE_NAME;PACKAGE_SOURCES;KEYSTORE_PASSWORD;KEY_PASSWORD;ANDROID_MIN_API;ANDROID_TARGET_API" "ANDROID_RESOURCES_PATH;DEPENDS;KEYSTORE;JAVA_SOURCES" ${ARGN})

    # extract the full path of the source target binary
    set(QT_ANDROID_APP_PATH "$<TARGET_FILE:${SOURCE_TARGET}>")
    if(QT_VERSION_MAJOR EQUAL 5)
        if(${Qt5Core_VERSION} VERSION_GREATER_EQUAL 5.14)
            set(QT_ANDROID_SUPPORT_MULTI_ABI ON)
        endif()
    else()
        set(QT_ANDROID_SUPPORT_MULTI_ABI ON)
    endif()
    message(STATUS "QT_ANDROID_SUPPORT_MULTI_ABI ${QT_ANDROID_SUPPORT_MULTI_ABI}")

    if(QT_ANDROID_SUPPORT_MULTI_ABI)
        # qtandroideploy will append by itself the ANDROID_ABI to the target name
        set(QT_ANDROID_APPLICATION_BINARY "${SOURCE_TARGET}")
    else()
        set(QT_ANDROID_APPLICATION_BINARY ${QT_ANDROID_APP_PATH})
    endif()


    # define the application name
    if(ARG_NAME)
        set(QT_ANDROID_APP_NAME ${ARG_NAME})
    else()
        set(QT_ANDROID_APP_NAME ${SOURCE_TARGET})
    endif()

    # define the application package name
    if(ARG_PACKAGE_NAME)
        set(QT_ANDROID_APP_PACKAGE_NAME ${ARG_PACKAGE_NAME})
    else()
        set(QT_ANDROID_APP_PACKAGE_NAME org.qtproject.${SOURCE_TARGET})
    endif()

    # detect latest Android SDK build-tools revision
    set(QT_ANDROID_SDK_BUILDTOOLS_REVISION "0.0.0")
    file(GLOB ALL_BUILD_TOOLS_VERSIONS RELATIVE ${QT_ANDROID_SDK_ROOT}/build-tools ${QT_ANDROID_SDK_ROOT}/build-tools/*)
    foreach(BUILD_TOOLS_VERSION ${ALL_BUILD_TOOLS_VERSIONS})
        # find subfolder with greatest version
        if (${BUILD_TOOLS_VERSION} VERSION_GREATER ${QT_ANDROID_SDK_BUILDTOOLS_REVISION})
            set(QT_ANDROID_SDK_BUILDTOOLS_REVISION ${BUILD_TOOLS_VERSION})
        endif()
    endforeach()
    message(STATUS "Detected Android SDK build tools version ${QT_ANDROID_SDK_BUILDTOOLS_REVISION}")

    # define the application source package directory
    if(ARG_PACKAGE_SOURCES)
        set(QT_ANDROID_APP_PACKAGE_SOURCE_ROOT ${ARG_PACKAGE_SOURCES})
        if(EXISTS "${ARG_PACKAGE_SOURCES}/AndroidManifest.xml")
            # custom manifest provided, use the provided source package directly
            set(QT_ANDROID_APP_PACKAGE_SOURCE_ROOT ${ARG_PACKAGE_SOURCES})
        elseif(EXISTS "${ARG_PACKAGE_SOURCES}/AndroidManifest.xml.in")
            # custom manifest template provided
            set(QT_ANDROID_MANIFEST_TEMPLATE "${ARG_PACKAGE_SOURCES}/AndroidManifest.xml.in")
        endif()
    else()
        # create our own configured package directory in build dir
        set(QT_ANDROID_APP_PACKAGE_SOURCE_ROOT "${CMAKE_CURRENT_BINARY_DIR}/package")

        # get version code from arguments, or generate a fixed one if not provided
        set(QT_ANDROID_APP_ACTIVITY_NAME ${ARG_ACTIVITY_NAME})
        if(NOT QT_ANDROID_APP_ACTIVITY_NAME)
            if(QT_VERSION_MAJOR EQUAL 6)
                set(QT_ANDROID_APP_ACTIVITY_NAME "org.qtproject.qt.android.bindings.QtActivity")
            else()
                set(QT_ANDROID_APP_ACTIVITY_NAME "org.qtproject.qt5.android.bindings.QtActivity")
            endif()
        endif()
        set(QT_ANDROID_APP_VERSION_CODE ${ARG_VERSION_CODE})
        if(NOT QT_ANDROID_APP_VERSION_CODE)
            set(QT_ANDROID_APP_VERSION_CODE 1)
        endif()

        # try to extract the app version from the target properties, or use the version code if not provided
        get_property(QT_ANDROID_APP_VERSION TARGET ${SOURCE_TARGET} PROPERTY VERSION)
        if(NOT QT_ANDROID_APP_VERSION)
            set(QT_ANDROID_APP_VERSION ${QT_ANDROID_APP_VERSION_CODE})
        endif()


        set(QT_ANDROID_MIN_API ${ARG_ANDROID_MIN_API})
        set(QT_ANDROID_TARGET_API ${ARG_ANDROID_TARGET_API})

        set(QT_ANDROID_ICON ${ARG_ICON})
        if(NOT QT_ANDROID_ICON)
            set(QT_ANDROID_ICON "@android:mipmap/sym_def_app_icon")
        endif()

        set(QT_ANDROID_SPLASH_SCREEN ${ARG_SPLASH_SCREEN})
        if(NOT QT_ANDROID_SPLASH_SCREEN)
            set(QT_ANDROID_SPLASH_SCREEN "@android:mipmap/sym_def_app_icon")
        endif()


        # create the manifest from the template file
        if(NOT QT_ANDROID_MANIFEST_TEMPLATE)
            if(QT_VERSION_MAJOR EQUAL 6)
                set(QT_ANDROID_MANIFEST_TEMPLATE "${QT_ANDROID_SOURCE_DIR}/AndroidManifest.xml.qt6.in")
            else()
                set(QT_ANDROID_MANIFEST_TEMPLATE "${QT_ANDROID_SOURCE_DIR}/AndroidManifest.xml.in")
            endif()
        endif()
        configure_file(${QT_ANDROID_MANIFEST_TEMPLATE} ${CMAKE_CURRENT_BINARY_DIR}/AndroidManifest.xml @ONLY)


#        set_property(TARGET ${SOURCE_TARGET} APPEND PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR
#                     ${QT_ANDROID_APP_PACKAGE_SOURCE_ROOT})

#         message(STATUS "QT_ANDROID_APP_PACKAGE_SOURCE_ROOT: ${QT_ANDROID_APP_PACKAGE_SOURCE_ROOT}")
        # define commands that will be added before the APK target build commands, to refresh the source package directory
        set(QT_ANDROID_PRE_COMMANDS ${QT_ANDROID_PRE_COMMANDS} COMMAND ${CMAKE_COMMAND} -E remove_directory ${QT_ANDROID_APP_PACKAGE_SOURCE_ROOT}) # clean the destination directory
        set(QT_ANDROID_PRE_COMMANDS ${QT_ANDROID_PRE_COMMANDS} COMMAND ${CMAKE_COMMAND} -E make_directory ${QT_ANDROID_APP_PACKAGE_SOURCE_ROOT}) # re-create it
        if(ARG_PACKAGE_SOURCES)
            set(QT_ANDROID_PRE_COMMANDS ${QT_ANDROID_PRE_COMMANDS} COMMAND ${CMAKE_COMMAND} -E copy_directory ${ARG_PACKAGE_SOURCES} ${QT_ANDROID_APP_PACKAGE_SOURCE_ROOT}) # copy the user package
        endif()
        set(QT_ANDROID_PRE_COMMANDS ${QT_ANDROID_PRE_COMMANDS} COMMAND ${CMAKE_COMMAND} -E remove_directory ${QT_ANDROID_APP_PACKAGE_SOURCE_ROOT}/res)  # it seems that recompiled libraries are not copied if we don't remove them first
        set(QT_ANDROID_PRE_COMMANDS ${QT_ANDROID_PRE_COMMANDS} COMMAND ${CMAKE_COMMAND} -E copy_directory ${ARG_ANDROID_RESOURCES_PATH} ${QT_ANDROID_APP_PACKAGE_SOURCE_ROOT}/res/)  # it seems that recompiled libraries are not copied if we don't remove them first
        set(QT_ANDROID_PRE_COMMANDS ${QT_ANDROID_PRE_COMMANDS} COMMAND ${CMAKE_COMMAND} -E copy_directory ${ARG_JAVA_SOURCES} ${QT_ANDROID_APP_PACKAGE_SOURCE_ROOT}/src)  # it seems that recompiled libraries are not copied if we don't remove them first
        set(QT_ANDROID_PRE_COMMANDS ${QT_ANDROID_PRE_COMMANDS} COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/AndroidManifest.xml ${QT_ANDROID_APP_PACKAGE_SOURCE_ROOT}/AndroidManifest.xml) # copy the generated manifest

        if(QT_VERSION_MAJOR EQUAL 6)
            set(QT_ANDROID_PRE_COMMANDS ${QT_ANDROID_PRE_COMMANDS} COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/qtdeploy.json ${CMAKE_CURRENT_BINARY_DIR}/android-${SOURCE_TARGET}-deployment-settings.json)
        else()
#            set(QT_ANDROID_PRE_COMMANDS ${QT_ANDROID_PRE_COMMANDS} COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/qtdeploy.json ${CMAKE_BINARY_DIR}/android_deployment_settings.json)
        endif()

#        COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_CURRENT_BINARY_DIR}/package/res # it seems that recompiled libraries are not copied if we don't remove them first
#        COMMAND ${CMAKE_COMMAND} -E copy_directory ${ARG_ANDROID_RESOURCES_PATH} ${CMAKE_CURRENT_BINARY_DIR}/package/res/
#        COMMAND ${CMAKE_COMMAND} -E copy_directory ${ARG_JAVA_SOURCES} ${CMAKE_CURRENT_BINARY_DIR}/package/src

    endif()

    # newer NDK toolchains don't define ANDROID_STL_PREFIX anymore,
    # so this is a fallback to the only supported value in recent versions
    if(NOT ANDROID_STL_PREFIX)
        if(ANDROID_STL MATCHES "^c\\+\\+_")
            set(ANDROID_STL_PREFIX llvm-libc++)
        endif()
    endif()
    if(NOT ANDROID_STL_PREFIX)
        message(WARNING "Failed to determine ANDROID_STL_PREFIX value for ANDROID_STL=${ANDROID_STL}")
    endif()

    # define the STL shared library path
    if(QT_ANDROID_SUPPORT_MULTI_ABI)
        # from Qt 5.14 qtandroideploy will find the correct stl.
        if(QT_VERSION_MAJOR EQUAL 6)
            set(QT_ANDROID_STL_PATH "${QT_ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${ANDROID_HOST_TAG}/sysroot/usr/lib/")
        else()
            set(QT_ANDROID_STL_PATH "${QT_ANDROID_NDK_ROOT}/sources/cxx-stl/${ANDROID_STL_PREFIX}/libs")
        endif()
    else()
        # define the STL shared library path
        # up until NDK r18, ANDROID_STL_SHARED_LIBRARIES is populated by the NDK's toolchain file
        # since NDK r19, the only option for a shared STL library is libc++_shared
        if(ANDROID_STL_SHARED_LIBRARIES)
            list(GET ANDROID_STL_SHARED_LIBRARIES 0 STL_LIBRARY_NAME) # we can only give one to androiddeployqt
            if(ANDROID_STL_PATH)
                set(QT_ANDROID_STL_PATH "${ANDROID_STL_PATH}/libs/${ANDROID_ABI}/lib${ANDROID_STL}.so")
            else()
                set(QT_ANDROID_STL_PATH "${QT_ANDROID_NDK_ROOT}/sources/cxx-stl/${ANDROID_STL_PREFIX}/libs/${ANDROID_ABI}/lib${ANDROID_STL}.so")
            endif()
        elseif(ANDROID_STL STREQUAL c++_shared)
            set(QT_ANDROID_STL_PATH "${QT_ANDROID_NDK_ROOT}/sources/cxx-stl/${ANDROID_STL_PREFIX}/libs/${ANDROID_ABI}/libc++_shared.so")
        else()
            set(QT_ANDROID_STL_PATH "${QT_ANDROID_NDK_ROOT}/sources/cxx-stl/${ANDROID_STL_PREFIX}/libs/${ANDROID_ABI}/lib${ANDROID_STL}.so")
            message(WARNING "ANDROID_STL (${ANDROID_STL}) isn't a known shared stl library."
                "You should consider setting ANDROID_STL to c++_shared (like Qt).")
            set(QT_ANDROID_STL_PATH "${QT_ANDROID_NDK_ROOT}/sources/cxx-stl/${ANDROID_STL_PREFIX}/libs/${ANDROID_ABI}/libc++_shared.so")
        endif()
    endif()
    message(STATUS "QT_ANDROID_STL_PATH ${QT_ANDROID_STL_PATH}")

    # From Qt 5.14 qtandroideploy "target-architecture" is no longer valid in input file
    # It have been replaced by "architectures": { "${ANDROID_ABI}": "${ANDROID_ABI}" }
    # This allow to package multiple ABI in a single apk
    # For now we only support single ABI build with this script (to ensure it work with Qt5.14 & Qt5.15)
    if(QT_ANDROID_SUPPORT_MULTI_ABI)
        if(QT_VERSION_MAJOR EQUAL 6)
            set(QT_ANDROID_ARCHITECTURES "\"${ANDROID_ABI}\":\"aarch64-linux-android\"")
        else()
            set(QT_ANDROID_ARCHITECTURES "\"${ANDROID_ABI}\":\"${ANDROID_ABI}\"")
        endif()
    endif()

    # set the list of dependant libraries
    if(ARG_DEPENDS)
        foreach(LIB ${ARG_DEPENDS})
            if(TARGET ${LIB})
                # item is a CMake target, extract the library path
                set(LIB_PATH "$<TARGET_FILE:${LIB}>")
                set(LIB ${LIB_PATH})
            endif()
            if(EXTRA_LIBS)
                set(EXTRA_LIBS "${EXTRA_LIBS},${LIB}")
            else()
                set(EXTRA_LIBS "${LIB}")
            endif()
        endforeach()
        set(QT_ANDROID_APP_EXTRA_LIBS "\"android-extra-libs\": \"${EXTRA_LIBS}\",")
    endif()

    # set some toolchain variables used by androiddeployqt;
    # unfortunately, Qt tries to build paths from these variables although these full paths
    # are already available in the toochain file, so we have to parse them
    message(STATUS "ANDROID_NDK: " ${ANDROID_NDK})
    message(STATUS "ANDROID_TOOLCHAIN_ROOT: " ${ANDROID_TOOLCHAIN_ROOT})
    string(REGEX MATCH "${ANDROID_NDK}/toolchains/(.*)/prebuilt/.*" ANDROID_TOOLCHAIN_PARSED ${ANDROID_TOOLCHAIN_ROOT})
    if(ANDROID_TOOLCHAIN_PARSED)
        set(QT_ANDROID_TOOLCHAIN_PREFIX ${CMAKE_MATCH_1})
    else()
        message(FATAL_ERROR "Failed to parse ANDROID_TOOLCHAIN_ROOT to get toolchain prefix and version")
    endif()

    # make sure that the output directory for the Android package exists
    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/libs/${ANDROID_ABI})

    if(ARG_QML_ROOT_PATH)
        set(QML_ROOT_PATH ${ARG_QML_ROOT_PATH})
    endif()

    # make sure that the output directory for the Android package exists
    if(QT_VERSION_MAJOR EQUAL 6)
        set(QT_ANDROID_APP_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/android-build)
        set(QT_ANDROID_QT_DEPLOY_VALUE "\"${ANDROID_ABI}\":\"${QT_ANDROID_QT_ROOT}\"")
        if(CMAKE_HOST_SYSTEM MATCHES "Darwin")
            set(QT_ANDROID_MACOS_QT_ROOT ${QT_ANDROID_QT_ROOT}/../macos)
        else()
            set(QT_ANDROID_MACOS_QT_ROOT ${QT_ANDROID_QT_ROOT}/../gcc_64)
        endif()
    else()
        set(QT_ANDROID_APP_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/${SOURCE_TARGET}-${ANDROID_ABI})
#        set(QT_ANDROID_APP_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/android-build)
        set(QT_ANDROID_MACOS_QT_ROOT ${QT_ANDROID_QT_ROOT})
    endif()
    file(MAKE_DIRECTORY ${QT_ANDROID_APP_BINARY_DIR}/libs/${ANDROID_ABI})


    # create the configuration file that will feed androiddeployqt
    # 1. replace placeholder variables at generation time
    if(QT_VERSION_MAJOR EQUAL 6)
        configure_file(${QT_ANDROID_SOURCE_DIR}/qtdeploy.json.qt6.in ${CMAKE_CURRENT_BINARY_DIR}/qtdeploy.json.configured @ONLY)
    else()
        configure_file(${QT_ANDROID_SOURCE_DIR}/qtdeploy.json.in ${CMAKE_CURRENT_BINARY_DIR}/qtdeploy.json.configured @ONLY)
    endif()
    # 2. evaluate generator expressions at build time
    file(GENERATE
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/qtdeploy.json
        INPUT ${CMAKE_CURRENT_BINARY_DIR}/qtdeploy.json.configured
        )

    # 3. Configure build.gradle to properly work with Android Studio import
    set(QT_ANDROID_NATIVE_API_LEVEL ${ANDROID_NATIVE_API_LEVEL})
    if(QT_VERSION_MAJOR EQUAL 6)
        configure_file(${QT_ANDROID_SOURCE_DIR}/build.gradle.qt6.in ${QT_ANDROID_APP_BINARY_DIR}/build.gradle @ONLY)
    else()
        configure_file(${QT_ANDROID_SOURCE_DIR}/build.gradle.in ${QT_ANDROID_APP_BINARY_DIR}/build.gradle @ONLY)
    endif()

    # check if the apk must be signed
    if(ARG_KEYSTORE)
        set(SIGN_OPTIONS --release --sign ${ARG_KEYSTORE} --tsa http://timestamp.digicert.com --digestalg SHA1 --sigalg MD5withRSA)
        if(ARG_KEYSTORE_PASSWORD)
            set(SIGN_OPTIONS ${SIGN_OPTIONS} --storepass ${ARG_KEYSTORE_PASSWORD} --keypass ${ARG_KEY_PASSWORD})
        endif()
    endif()

    # check if the apk must be installed to the device
    if(ARG_INSTALL)
        set(INSTALL_OPTIONS --reinstall)
    endif()

    # specify the Android API level
    if(ARG_ANDROID_TARGET_API)
        set(TARGET_LEVEL_OPTIONS --android-platform android-${ARG_ANDROID_TARGET_API})
    endif()

    message(STATUS "CMAKE_CURRENT_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}")
    message(STATUS "QT_ANDROID_APP_BINARY_DIR ${QT_ANDROID_APP_BINARY_DIR}")

    # create a custom command that will run the androiddeployqt utility to prepare the Android package
    add_custom_target(
        ${TARGET}
        ALL
        DEPENDS ${SOURCE_TARGET}
        ${QT_ANDROID_PRE_COMMANDS}
        COMMAND ${CMAKE_COMMAND} -E remove_directory ${QT_ANDROID_APP_BINARY_DIR}/libs/${ANDROID_ABI} # it seems that recompiled libraries are not copied if we don't remove them first
        COMMAND ${CMAKE_COMMAND} -E make_directory ${QT_ANDROID_APP_BINARY_DIR}/libs/${ANDROID_ABI}
        COMMAND ${CMAKE_COMMAND} -E copy ${QT_ANDROID_APP_PATH} ${QT_ANDROID_APP_BINARY_DIR}/libs/${ANDROID_ABI}
        COMMAND ${QT_ANDROID_MACOS_QT_ROOT}/bin/androiddeployqt --verbose --output ${QT_ANDROID_APP_BINARY_DIR} --input ${CMAKE_CURRENT_BINARY_DIR}/qtdeploy.json --gradle ${TARGET_LEVEL_OPTIONS} ${INSTALL_OPTIONS} ${SIGN_OPTIONS}
        )


endmacro()
