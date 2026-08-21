# Copyright (c) 2022, Cedric Velandres
# SPDX-License-Identifier: MIT

include_guard(GLOBAL)

if(__KCONFIG_CMAKE_INCLUDE_GUARD__)
    return()
endif()

set(__KCONFIG_CMAKE_INCLUDE_GUARD__ TRUE)

# Minimum version
cmake_minimum_required(VERSION 3.19)

# Module needs git
find_package(Git REQUIRED)
# scripts needs python (and prefer python3)
find_package(Python3 REQUIRED COMPONENTS Interpreter)

# #######################################################################
# kconfig_check_variable <name> <message>
#
# Helper macro to check if variable is set
# name: variable name
# message: error message
function(kconfig_check_variable name message)
    if(NOT ${name})
        message(FATAL_ERROR "${name} not set, ${message}")
    endif()
endfunction()

# #######################################################################
# kconfig_default_variable <name> <default>
#
# Helper macro to set default values to variables
# name: variable name
# default: default value
macro(kconfig_default_variable name default)
    if(NOT DEFINED ${name})
        set(${name} "${default}")
        message(DEBUG "${name} not set, defaulting to ${default}")
    endif()
endmacro()

# #######################################################################
# kconfig_make_dir <path>
#
# Helper macro to create parent directory for files
# path: path to root kconfig
macro(kconfig_make_dir path)
    # Create parent directory, since genconfig does not create it
    file(MAKE_DIRECTORY "${path}")
endmacro()

# #######################################################################
# kconfig_make_parent_dir <path>
#
# Helper macro to create parent directory for files
# path: path to root kconfig
macro(kconfig_make_parent_dir path)
    # Create parent directory, since genconfig does not create it
    get_filename_component(parent_dir "${path}" DIRECTORY)
    kconfig_make_dir("${parent_dir}")
endmacro()

# #######################################################################
# kconfig_make_absolute <path>
#
# Helper macro to convert paths to absolute paths
# path: path to convert
macro(kconfig_make_absolute path)
    # Create parent directory, since genconfig does not create it
    get_filename_component(abspath "${${path}}" ABSOLUTE)
        set(${path} "${abspath}")
endmacro()

# #######################################################################
# kconfig_find_bin <paths> <name> <bin [...]>
#
# Finds program with name bin... and stores it to name
# paths: program path to search
# name: variable name to store path to program
# bin...: binary to find
macro(kconfig_find_bin name bin)
    if(NOT ${name})
        message(CHECK_START "Looking for ${bin}")
        if(NOT ${name})
            find_program(${name} NAMES ${bin} PATHS ${ARGN} HINTS ${ARGN})

            if(NOT ${name})
                set(${name}_FOUND 0)
                message(CHECK_FAIL "not found")
            else()
                set(${name}_FOUND 1)
                message(CHECK_PASS "found")
            endif()
        elseif(NOT EXISTS "${${name}}")
            set(${name}_FOUND 0)
            message(CHECK_FAIL "not found")
        else()
            set(${name}_FOUND 1)
            message(CHECK_PASS "found")
        endif()
    endif()
endmacro()

# #######################################################################
# kconfig_check_module
#
# Checks if python kconfiglib module is available
macro(kconfig_check_module)
    if (NOT __KCONFIG_MODULE_FOUND)
        message(CHECK_START "Looking for kconfiglib")

        execute_process(COMMAND
            ${Python3_EXECUTABLE} -c "import kconfiglib"
            RESULT_VARIABLE not_found
            OUTPUT_QUIET
            ERROR_QUIET
            )

        if(not_found)
            message(FATAL_ERROR "kconfiglib not found. Install with \"pip install kconfiglib\"")
        else()
            message(CHECK_PASS "found")
            set(__KCONFIG_MODULE_FOUND 1 CACHE STRING "")
        endif()
    endif()
endmacro()

# #######################################################################
# kconfig_check_binaries
#
# Checks if required binaries are available
macro(kconfig_check_binaries)

    kconfig_check_module()

    kconfig_find_bin(KCONFIG_SAVEDEFCONFIG_BIN savedefconfig)
    kconfig_find_bin(KCONFIG_MENUCONFIG_BIN menuconfig)
    kconfig_find_bin(KCONFIG_DEFCONFIG_BIN defconfig)
    kconfig_find_bin(KCONFIG_GENCONFIG_BIN genconfig)
    kconfig_find_bin(KCONFIG_OLDCONFIG_BIN oldconfig)
    kconfig_find_bin(KCONFIG_ALLYESCONFIG_BIN allyesconfig)
    kconfig_find_bin(KCONFIG_ALLNOCONFIG_BIN allnoconfig)
    kconfig_find_bin(KCONFIG_ALLMODCONFIG_BIN allmodconfig)
    kconfig_find_bin(KCONFIG_ALLDEFCONFIG_BIN alldefconfig)

    # Verify if vars are set
    kconfig_check_variable(KCONFIG_SAVEDEFCONFIG_BIN "savedefconfig not found")
    kconfig_check_variable(KCONFIG_MENUCONFIG_BIN "menuconfig not found")
    kconfig_check_variable(KCONFIG_DEFCONFIG_BIN "defconfig not found")
    kconfig_check_variable(KCONFIG_GENCONFIG_BIN "genconfig not found")
    kconfig_check_variable(KCONFIG_OLDCONFIG_BIN "oldconfig not found")
    kconfig_check_variable(KCONFIG_ALLYESCONFIG_BIN "allyesconfig not found")
    kconfig_check_variable(KCONFIG_ALLNOCONFIG_BIN "allnoconfig not found")
    kconfig_check_variable(KCONFIG_ALLMODCONFIG_BIN "allmodconfig not found")
    kconfig_check_variable(KCONFIG_ALLDEFCONFIG_BIN "alldefconfig not found")

endmacro()

# #######################################################################
# kconfig_defconfig <kconfig_file> <defconfig> <dotconfig> <autoheader> <autoconf> <tristate>
#
# Generate .config from given defconfig
# kconfig_file: path to root kconfig
# defconfig: path to defconfig
# dotconfig: path to .config
# autoheader: path to write "autoconf.h"
# autoconf: path to write "auto.conf" file
# tristate: path to write "tristate.conf"
function(kconfig_defconfig kconfig_file defconfig dotconfig autoheader autoconf tristate)
    message(DEBUG "kconfig_defconfig:")
    message(DEBUG "\t KCONFIG:            ${kconfig_file}")
    message(DEBUG "\t DEFCONFIG:          ${defconfig}")
    message(DEBUG "\t KCONFIG_CONFIG:     ${dotconfig}")
    message(DEBUG "\t KCONFIG_AUTOHEADER: ${autoheader}")
    message(DEBUG "\t KCONFIG_AUTOCONFIG: ${autoconf}")
    message(DEBUG "\t KCONFIG_TRISTATE:   ${tristate}")

    execute_process(
        COMMAND ${CMAKE_COMMAND} -E env
            KCONFIG_AUTOHEADER=${autoheader}
            KCONFIG_AUTOCONFIG=${autoconf}
            KCONFIG_TRISTATE=${tristate}
            KCONFIG_CONFIG=${dotconfig}
            CONFIG_=${KCONFIG_CONFIG_PREFIX}
            srctree=${KCONFIG_SRCTREE}
            ${KCONFIG_DEFCONFIG_BIN} 
            --kconfig ${kconfig_file}
            ${defconfig}
            WORKING_DIRECTORY ${KCONFIG_BINARY_DIR}
            OUTPUT_QUIET
            RESULT_VARIABLE ret
    )

    if(ret)
        message(FATAL_ERROR "could not create initial .config: ${ret}")
    endif()
endfunction()

# #######################################################################
# __kconfig_setup_custom_target
#
# Creates the custom targets (menuconfig, savedefconfig, etc)
macro(__kconfig_setup_custom_targets)
    # Add menuconfig target
    add_custom_target(
        menuconfig
        ${CMAKE_COMMAND} -E env
        KCONFIG_AUTOHEADER=${KCONFIG_AUTOHEADER_PATH}
        KCONFIG_AUTOCONFIG=${KCONFIG_AUTOCONFIG_PATH}
        KCONFIG_TRISTATE=${KCONFIG_TRISTATE_PATH}
        KCONFIG_CONFIG=${KCONFIG_DOTCONFIG_PATH}
        CONFIG_=${KCONFIG_CONFIG_PREFIX}
        srctree=${KCONFIG_SRCTREE}
        ${KCONFIG_MENUCONFIG_BIN}
        ${KCONFIG_MERGED_KCONFIG_PATH}
        WORKING_DIRECTORY ${KCONFIG_BINARY_DIR}
        USES_TERMINAL
    )

    # savedefconfig target
    add_custom_target(
        savedefconfig
        COMMAND ${CMAKE_COMMAND} -E echo "Saving defconfig to ${KCONFIG_DEFCONFIG}"
        COMMAND ${CMAKE_COMMAND} -E env
        KCONFIG_AUTOHEADER=${KCONFIG_AUTOHEADER_PATH}
        KCONFIG_AUTOCONFIG=${KCONFIG_AUTOCONFIG_PATH}
        KCONFIG_TRISTATE=${KCONFIG_TRISTATE_PATH}
        KCONFIG_CONFIG=${KCONFIG_DOTCONFIG_PATH}
        CONFIG_=${KCONFIG_CONFIG_PREFIX}
        srctree=${KCONFIG_SRCTREE}
        ${KCONFIG_SAVEDEFCONFIG_BIN}
        --out ${KCONFIG_DEFCONFIG}
        --kconfig ${KCONFIG_MERGED_KCONFIG_PATH}
        WORKING_DIRECTORY ${KCONFIG_BINARY_DIR}
        USES_TERMINAL
    )

    # allyesconfig
    add_custom_target(
        allyesconfig
        COMMAND ${CMAKE_COMMAND} -E echo "Saving allyesconfig to ${KCONFIG_DOTCONFIG_PATH}"
        COMMAND ${CMAKE_COMMAND} -E env
        KCONFIG_AUTOHEADER=${KCONFIG_AUTOHEADER_PATH}
        KCONFIG_AUTOCONFIG=${KCONFIG_AUTOCONFIG_PATH}
        KCONFIG_TRISTATE=${KCONFIG_TRISTATE_PATH}
        KCONFIG_CONFIG=${KCONFIG_DOTCONFIG_PATH}
        CONFIG_=${KCONFIG_CONFIG_PREFIX}
        srctree=${KCONFIG_SRCTREE}
        ${KCONFIG_ALLYESCONFIG_BIN}
        ${KCONFIG_MERGED_KCONFIG_PATH}
        WORKING_DIRECTORY ${KCONFIG_BINARY_DIR}
        USES_TERMINAL
    )

    # allnoconfig
    add_custom_target(
        allnoconfig
        COMMAND ${CMAKE_COMMAND} -E echo "Saving defconfig to ${KCONFIG_DOTCONFIG_PATH}"
        COMMAND ${CMAKE_COMMAND} -E env
        KCONFIG_AUTOHEADER=${KCONFIG_AUTOHEADER_PATH}
        KCONFIG_AUTOCONFIG=${KCONFIG_AUTOCONFIG_PATH}
        KCONFIG_TRISTATE=${KCONFIG_TRISTATE_PATH}
        KCONFIG_CONFIG=${KCONFIG_DOTCONFIG_PATH}
        CONFIG_=${KCONFIG_CONFIG_PREFIX}
        srctree=${KCONFIG_SRCTREE}
        ${KCONFIG_ALLNOCONFIG_BIN}
        ${KCONFIG_MERGED_KCONFIG_PATH}
        WORKING_DIRECTORY ${KCONFIG_BINARY_DIR}
        USES_TERMINAL
    )

    # allmodconfig
    add_custom_target(
        allmodconfig
        COMMAND ${CMAKE_COMMAND} -E echo "Saving defconfig to ${KCONFIG_DEFCONFIG}"
        COMMAND ${CMAKE_COMMAND} -E env
        KCONFIG_AUTOHEADER=${KCONFIG_AUTOHEADER_PATH}
        KCONFIG_AUTOCONFIG=${KCONFIG_AUTOCONFIG_PATH}
        KCONFIG_TRISTATE=${KCONFIG_TRISTATE_PATH}
        KCONFIG_CONFIG=${KCONFIG_DOTCONFIG_PATH}
        CONFIG_=${KCONFIG_CONFIG_PREFIX}
        srctree=${KCONFIG_SRCTREE}
        ${KCONFIG_ALLMODCONFIG_BIN}
        ${KCONFIG_MERGED_KCONFIG_PATH}
        WORKING_DIRECTORY ${KCONFIG_BINARY_DIR}
        USES_TERMINAL
    )

    # alldefconfig
    add_custom_target(
        alldefconfig
        COMMAND ${CMAKE_COMMAND} -E echo "Saving defconfig to ${KCONFIG_DOTCONFIG_PATH}"
        COMMAND ${CMAKE_COMMAND} -E env
        KCONFIG_AUTOHEADER=${KCONFIG_AUTOHEADER_PATH}
        KCONFIG_AUTOCONFIG=${KCONFIG_AUTOCONFIG_PATH}
        KCONFIG_TRISTATE=${KCONFIG_TRISTATE_PATH}
        KCONFIG_CONFIG=${KCONFIG_DOTCONFIG_PATH}
        CONFIG_=${KCONFIG_CONFIG_PREFIX}
        srctree=${KCONFIG_SRCTREE}
        ${KCONFIG_ALLDEFCONFIG_BIN}
        ${KCONFIG_MERGED_KCONFIG_PATH}
        WORKING_DIRECTORY ${KCONFIG_BINARY_DIR}
        USES_TERMINAL
    )
endmacro()

# #######################################################################
# kconfig_merge_kconfigs <merged_path> <source_prop>
#
# Generate merged root kconfig for all kconfig in project added via kconfig_add_kconfig
# merged_path: path to write merged kconfig
# source_prop: name of global property holding all kconfig paths
function(kconfig_merge_kconfigs merged_path source_var)
    message(DEBUG "kconfig_merge_kconfigs:")
    message(STATUS "Generating merged Kconfig:")
    message(DEBUG "\t merged_path:     ${merged_path}")
    message(DEBUG "\t source_var:      ${source_var}")
    get_property(kconfig_sources GLOBAL PROPERTY ${source_var})
    message(DEBUG "\t kconfig_sources: ${kconfig_sources}")

    execute_process(COMMAND
        ${CMAKE_COMMAND} -E env
        KCONFIG_AUTOHEADER=${KCONFIG_AUTOHEADER_PATH}
        KCONFIG_AUTOCONFIG=${KCONFIG_AUTOCONFIG_PATH}
        KCONFIG_TRISTATE=${KCONFIG_TRISTATE_PATH}
        KCONFIG_CONFIG=${KCONFIG_DOTCONFIG_PATH}
        CONFIG_=${KCONFIG_CONFIG_PREFIX}
        srctree=${KCONFIG_SRCTREE}
        ${Python3_EXECUTABLE}
        ${KCONFIG_MERGE_PYBIN}
        --silent
        --list-sources
        --kconfig ${merged_path}
        --title ${PROJECT_NAME}
        --sources ${kconfig_sources}
        WORKING_DIRECTORY ${KCONFIG_BINARY_DIR}
        OUTPUT_VARIABLE output
        # ERROR_QUIET
        RESULT_VARIABLE ret
    )

    if(ret)
        message(FATAL_ERROR "error during kconfig merge: ${ret}")
    endif()

    # set configure depends to kconfig sources
    string(REPLACE "\n" ";" _sources "${output}")
    list(FILTER _sources EXCLUDE REGEX "^$")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_sources}")
endfunction()

# #######################################################################
# kconfig_add_fragment <fragment>
#
# Add a config fragment to the build
# fragment: config fragment to add
function(kconfig_add_fragment fragment)
    message(DEBUG "kconfig_add_fragment:")
    message(DEBUG "\t fragment: ${fragment}")

    set_property(GLOBAL APPEND PROPERTY KCONFIG_FRAGMENTS "${fragment}")
endfunction()

# #######################################################################
# kconfig_create_cache_fragment <cache_fragment>
#
# Parse cmake cache variables for cli given kconfig settings
# retrieves cache fragments from global property: KCONFIG_CACHE_CONFIGS
# cache_fragment file to write config fragment
function(kconfig_create_cache_fragment cache_fragment)
    message(DEBUG "Generating cache kconfig fragment: ${cache_fragment}")
    message(DEBUG "kconfig_create_cache_fragment:")
    message(DEBUG "\t cache_fragment: ${cache_fragment}")
    
    get_property(_configs GLOBAL PROPERTY KCONFIG_CACHE_CONFIGS)
    foreach(_config ${_configs})
        message(DEBUG "\t   config: ${_config}")
        file(APPEND ${cache_fragment} "${_config}\n")
    endforeach()

    
    file(APPEND ${cache_fragment} "\n") # empty write so file is created if no cache config
    set_property(GLOBAL APPEND PROPERTY KCONFIG_FRAGMENTS "${cache_fragment}")
endfunction()

# #######################################################################
# kconfig_merge_fragments <merged_config>
#
# Merged .config together with cache fragments
# kconfig_file: path to kconfig file
# merged_config: path to merged config
# plus additional config files
function(kconfig_merge_fragments kconfig_file merged_config)
    message(DEBUG "kconfig_merge_fragments:")
    message(DEBUG "\t merged_config:  ${merged_config}")

    get_property(_fragments GLOBAL PROPERTY KCONFIG_FRAGMENTS)
    message(DEBUG "\t fragments: ${_fragments}")

    execute_process(COMMAND
        ${CMAKE_COMMAND} -E env
        KCONFIG_AUTOHEADER=${KCONFIG_AUTOHEADER_PATH}
        KCONFIG_AUTOCONFIG=${KCONFIG_AUTOCONFIG_PATH}
        KCONFIG_TRISTATE=${KCONFIG_TRISTATE_PATH}
        KCONFIG_CONFIG=${KCONFIG_DOTCONFIG_PATH}
        CONFIG_=${KCONFIG_CONFIG_PREFIX}
        srctree=${KCONFIG_SRCTREE}
        ${Python3_EXECUTABLE} ${KCONFIG_MERGE_FRAGMENTS_PYBIN}
        ${kconfig_file}
        ${merged_config}
        ${_fragments} ${ARGN}
        WORKING_DIRECTORY ${KCONFIG_BINARY_DIR}
        # ERROR_QUIET # will also disable warnings so prefer not to
        OUTPUT_QUIET
        RESULT_VARIABLE ret)

    if (ret)
        message(FATAL_ERROR "error when merging configs: ${ret}")
    endif()
endfunction()

# #######################################################################
# kconfig_import_cache_variables <config_prefix> <cache_fragment> <config_list>
#
# Parse cmake cache variables for cli given kconfig settings
# kconfig cache keys are stored in global property: KCONFIG_CACHE_CONFIGS
# config_prefix config prefix
# config_list: variable store cache config keys
function(kconfig_import_cache_variables config_prefix)
    message(DEBUG "kconfig_import_cache_variables:")
    message(DEBUG "\t config_prefix:  ${config_prefix}")
    get_cmake_property(cache_variables CACHE_VARIABLES)

    foreach(var ${cache_variables})
        if("${var}" MATCHES "^${config_prefix}")
            set(_config "${var}=${${var}}")
            set_property(GLOBAL APPEND PROPERTY KCONFIG_CACHE_CONFIGS "${_config}")

            if(KCONFIG_USE_VARIABLES)
                # unset the cache config, will create a config fragment instead
                unset(${var} CACHE)
            endif()
        endif()
    endforeach()
endfunction()

# #######################################################################
# kconfig_split_config <in> <name> <value>
#
# Parse input string and split config to name and value
# in: config string 
# name: variable name to store name
# value: variable name to store value
function(kconfig_split_config in name value)
    
    if("${in}" MATCHES "^([^=]+)=(.+)$")
        set(${name} ${CMAKE_MATCH_1} PARENT_SCOPE)
        set(${value} ${CMAKE_MATCH_2} PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Could not parse config string: ${in}")
    endif()
endfunction()

# #######################################################################
# kconfig_parse_defconfig <config_prefix> <config_file> <config_list> <cache>
#
# Parse kconfig defconfig and store to global property KCONFIG_KEYS
# import all config to cmake variable namespace
# config_prefix config prefix in file
# config_file file to parse
# config_list will contain all configs parsed from file
# cache controls whether keys are declared as cache variable
function(kconfig_import_config config_prefix config_file config_list cache)
    # Imports defconfig with format CONFIG_* to cmake variables
    # ie. CONFIG_OPTION_X=y -> set(CONFIG_OPTION_X "ON")
    # ie. CONFIG_OPTION_X=n -> set(CONFIG_OPTION_X "OFF")
    message(DEBUG "kconfig_import_config")
    message(DEBUG "   config_prefix: ${config_prefix}")
    message(DEBUG "   config_file:   ${config_file}")
    message(DEBUG "   config_list:   ${config_list}")
    message(DEBUG "   cache:         ${cache}")
    file(STRINGS ${config_file} DEFCONFIG_LIST)

    # clear property
    set_property(GLOBAL PROPERTY KCONFIG_KEYS )

    foreach(CONFIG ${DEFCONFIG_LIST})
        # each CONFIG line should look like: <PREFIX>_OPTION=y
        if("${CONFIG}" MATCHES "^#[ \t\r\n]*([^ ]+) is not set")
            set(CONFIG_NAME "${CMAKE_MATCH_1}")
            set(CONFIG_VALUE "N")
        elseif("${CONFIG}" MATCHES "^([^=]+)=(.+)$")
            set(CONFIG_NAME "${CMAKE_MATCH_1}")
            set(CONFIG_VALUE "${CMAKE_MATCH_2}")
        else()
            # skip comments
            continue()
        endif()

        string(TOUPPER "${CONFIG_VALUE}" CONFIG_VALUE)
        message(DEBUG "\t ${CONFIG_NAME}: ${CONFIG_VALUE}")

        # Convert Y -> ON, N -> OFF
        if("${CONFIG_VALUE}" MATCHES "Y")
            set(CONFIG_VALUE ON)
        elseif("${CONFIG_VALUE}" MATCHES "N")
            set(CONFIG_VALUE OFF)
        endif()

        if(KCONFIG_USE_VARIABLES)
            set("${CONFIG_NAME}" ${CONFIG_VALUE} PARENT_SCOPE)
        endif()

        # add to list
        list(APPEND CONFIG_DEFCONFIG_LIST "${CONFIG_NAME}")
        set_property(GLOBAL APPEND PROPERTY KCONFIG_KEYS "${CONFIG_NAME}=${CONFIG_VALUE}")
    endforeach()

    if(KCONFIG_USE_VARIABLES)
        # set config list
        set(${config_list} ${CONFIG_DEFCONFIG_LIST} PARENT_SCOPE)
    endif()
endfunction()

# #######################################################################
# kconfig_add_kconfig <kconfig_file>
#
# add kconfig file to project
# Stores list of all kconfigs to global property: KCONFIG_CONFIG_SOURCES
# kconfig_file: path to kconfig file to add
function(kconfig_add_kconfig kconfig_file)
    message(DEBUG "kconfig_add_kconfig")
    message(DEBUG "   kconfig_file:   ${kconfig_file}")

    if(NOT IS_ABSOLUTE ${kconfig_file})
        set(_kconfig_file "${CMAKE_CURRENT_SOURCE_DIR}/${kconfig_file}")
    else()
        set(_kconfig_file "${kconfig_file}")
    endif()

    # add kconfig file to project
    set_property(GLOBAL APPEND PROPERTY KCONFIG_CONFIG_SOURCES "${_kconfig_file}")
endfunction()

# #######################################################################
# kconfig_add_target <target> <kconfig>
#
# setup target with kconfig
# target: target to configure
function(kconfig_add_target target)
    message(DEBUG "kconfig_add_target")
    message(DEBUG "   target:   ${target}")

    # add target to list of kconfig targets
    set_property(GLOBAL APPEND PROPERTY KCONFIG_TARGETS "${target}")
endfunction()

# #######################################################################
# kconfig_genconfig <kconfig_root> <dotconfig> <autoheader> <autoconf> <tristate>
#
# kconfig_file: path to root kconfig
# dotconfig: path to .config
# autoheader: path to write "autoconf.h"
# autoconf: path to write "auto.conf" file
# tristate: path to write "tristate.conf"
function(kconfig_genconfig kconfig_file dotconfig autoheader autoconf tristate)
    message(STATUS "Regenerating configs...")
    message(DEBUG "kconfig_genconfig:")
    message(DEBUG "\t KCONFIG:            ${kconfig_file}")
    message(DEBUG "\t KCONFIG_CONFIG:     ${dotconfig}")
    message(DEBUG "\t KCONFIG_AUTOHEADER: ${autoheader}")
    message(DEBUG "\t KCONFIG_AUTOCONFIG: ${autoconf}")
    message(DEBUG "\t KCONFIG_TRISTATE:   ${tristate}")

    execute_process(COMMAND
        ${CMAKE_COMMAND} -E env
        KCONFIG_AUTOHEADER=${autoheader}
        KCONFIG_AUTOCONFIG=${autoconf}
        KCONFIG_TRISTATE=${tristate}
        KCONFIG_CONFIG=${dotconfig}
        CONFIG_=${KCONFIG_CONFIG_PREFIX}
        srctree=${KCONFIG_SRCTREE}
        ${KCONFIG_GENCONFIG_BIN}
        ${kconfig_file}
        WORKING_DIRECTORY ${KCONFIG_BINARY_DIR}
        OUTPUT_QUIET
        RESULT_VARIABLE ret
    )

    if(ret)
        message(FATAL_ERROR "could not generate config header: ${ret}")
    endif()
endfunction()

# #######################################################################
# kconfig_print_configs
#
# Print all configs stored in global property KCONFIG_KEYS
# Enable via KCONFIG_PRINT_SUMMARY
function(kconfig_print_configs)
    if (KCONFIG_PRINT_SUMMARY)
        message(DEBUG "kconfig_print_configs:")

        get_property(_keys GLOBAL PROPERTY KCONFIG_KEYS)

        message(STATUS "Kconfig final config list")

        foreach(key ${_keys})
            kconfig_split_config("${key}" name value)
            message(STATUS "\t ${name}: ${value}")
        endforeach()
    endif()
endfunction()

# #######################################################################
# kconfig_set_global_properties
#
# Import config keys into cmake cache variables
# Enable via KCONFIG_SET_GLOBAL_PROPERTIES
macro(kconfig_set_global_properties)
    if (KCONFIG_SET_GLOBAL_PROPERTIES)
        message(DEBUG "kconfig_set_global_properties:")

        get_property(_keys GLOBAL PROPERTY KCONFIG_KEYS)

        foreach(key ${_keys})
            kconfig_split_config("${key}" name value)
            set_property(GLOBAL PROPERTY ${name} "${value}")
        endforeach()
    endif()
endmacro()

# #######################################################################
# Kconfig setup

# Check defaults for variable
kconfig_default_variable(KCONFIG_DEFCONFIG "${CMAKE_SOURCE_DIR}/configs/defconfig")
kconfig_default_variable(KCONFIG_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")
kconfig_default_variable(KCONFIG_SRCTREE "${CMAKE_SOURCE_DIR}")
kconfig_default_variable(KCONFIG_BINARY_DIR "${CMAKE_BINARY_DIR}/Kconfig")
kconfig_default_variable(KCONFIG_BINARY_TMP_DIR "${KCONFIG_BINARY_DIR}/tmp")
kconfig_default_variable(KCONFIG_CONFIG_PREFIX "CONFIG_")
kconfig_default_variable(KCONFIG_INCLUDE_PATH "${KCONFIG_BINARY_DIR}/include")
kconfig_default_variable(KCONFIG_TRISTATE_PATH "${KCONFIG_INCLUDE_PATH}/config/tristate.conf")
kconfig_default_variable(KCONFIG_AUTOCONFIG_PATH "${KCONFIG_INCLUDE_PATH}/config/auto.conf")
kconfig_default_variable(KCONFIG_AUTOHEADER_PATH "${KCONFIG_INCLUDE_PATH}/generated/config.h")
kconfig_default_variable(KCONFIG_MERGED_KCONFIG_PATH "${KCONFIG_BINARY_DIR}/Kconfig")
kconfig_default_variable(KCONFIG_DOTCONFIG_PATH "${KCONFIG_BINARY_DIR}/.config")
kconfig_default_variable(KCONFIG_PREINCLUDE_AUTOCONF ON)
kconfig_default_variable(KCONFIG_USE_VARIABLES OFF)
kconfig_default_variable(KCONFIG_SET_GLOBAL_PROPERTIES ON)
kconfig_default_variable(KCONFIG_PRINT_SUMMARY OFF)

# Create paths
kconfig_make_dir(${KCONFIG_BINARY_TMP_DIR})
kconfig_make_parent_dir(${KCONFIG_TRISTATE_PATH})
kconfig_make_parent_dir(${KCONFIG_AUTOCONFIG_PATH})
kconfig_make_parent_dir(${KCONFIG_AUTOHEADER_PATH})
kconfig_make_parent_dir(${KCONFIG_MERGED_KCONFIG_PATH})
kconfig_make_parent_dir(${KCONFIG_DOTCONFIG_PATH})

# Check if binaries are found, else download prebuilts
kconfig_check_binaries()
# Set KConfig binary paths
set(KCONFIG_MERGE_PYBIN "${KCONFIG_MODULE_PATH}/kconfig-merge.py")
set(KCONFIG_MERGE_FRAGMENTS_PYBIN "${KCONFIG_MODULE_PATH}/merge-fragments.py")

# check if KCONFIG_DEFCONFIG exists
kconfig_make_absolute(KCONFIG_DEFCONFIG)
if(NOT EXISTS "${KCONFIG_DEFCONFIG}")
    kconfig_make_parent_dir(${KCONFIG_DEFCONFIG_DIR})
    file(TOUCH ${KCONFIG_DEFCONFIG})
endif()

# Add kconfig include dir to include directories
include_directories("${KCONFIG_INCLUDE_PATH}")

# Create the custom targets (menuconfig, etc)
__kconfig_setup_custom_targets()

# dummy target to sanity check kconfig generated files
add_custom_target(kconfig_sanity
    DEPENDS
    ${KCONFIG_DOTCONFIG_PATH}
    ${KCONFIG_AUTOHEADER_PATH}
    ${KCONFIG_MERGED_KCONFIG_PATH}
    ${KCONFIG_AUTOCONFIG_PATH}
    ${KCONFIG_TRISTATE_PATH})

# Reconfigure cmake when config changes
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${KCONFIG_DEFCONFIG}")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${KCONFIG_DOTCONFIG_PATH}")

# Add Kconfig binary dir to clean targets
set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_CLEAN_FILES "${KCONFIG_BINARY_DIR}")

# Import defconfig initially if dotconfig does not exist
if(NOT EXISTS ${KCONFIG_DOTCONFIG_PATH})
    kconfig_import_config("${KCONFIG_CONFIG_PREFIX}" "${KCONFIG_DEFCONFIG}" KCONFIG_KEYS ON)
else()
    kconfig_import_config("${KCONFIG_CONFIG_PREFIX}" "${KCONFIG_DOTCONFIG_PATH}" KCONFIG_KEYS ON)
endif()

# #######################################################################
# Everything under here are run during post configure

# #######################################################################
# __kconfig_configure_targets <config_keys>
#
# setup target with kconfig
# keys are retrieved from global property: KCONFIG_KEYS
# keys to configure targets: target to configure
macro(__kconfig_configure_targets config_keys)
    message(DEBUG "__kconfig_configure_targets")
    message(DEBUG "   config_keys:   ${config_keys}")
    get_property(_kconfig_targets GLOBAL PROPERTY KCONFIG_TARGETS)
    get_property(_keys GLOBAL PROPERTY KCONFIG_KEYS)
    message(DEBUG "   targets:   ${_kconfig_targets}")

    foreach(tgt ${_kconfig_targets})
        foreach(key ${_keys})
            kconfig_split_config("${key}" name value)
            set_target_properties(${tgt} PROPERTIES ${name} ${value})
        endforeach()

        get_target_property(TARGET_TYPE ${tgt} TYPE)

        # if preinclude is enabled
        if(KCONFIG_PREINCLUDE_AUTOCONF)
            if(TARGET_TYPE STREQUAL "INTERFACE_LIBRARY")
                target_compile_options(${tgt} INTERFACE
                    $<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:-include;${KCONFIG_AUTOHEADER_PATH}>)
            else()
                target_precompile_headers(${tgt} PUBLIC "${KCONFIG_AUTOHEADER_PATH}")
            endif()
        endif()
    endforeach()
endmacro()

# #######################################################################
# __kconfig_post_configure
#
# This macro needs to be called last, preferably by deferred call in top level CMakeLists
macro(__kconfig_post_configure)
    # Generate merged root kconfig
    kconfig_merge_kconfigs("${KCONFIG_MERGED_KCONFIG_PATH}" KCONFIG_CONFIG_SOURCES)

    # Convert to cache config variables to config fragment
    kconfig_import_cache_variables("${KCONFIG_CONFIG_PREFIX}" KCONFIG_CACHE_CONFIGS)
    kconfig_create_cache_fragment("${KCONFIG_BINARY_DIR}/fragments/cache.fragment")

    # Generate initial .config file if .config does not exist yet
    if(NOT EXISTS ${KCONFIG_DOTCONFIG_PATH})
        set(defconfig_tmp "${KCONFIG_BINARY_DIR}/.defconfig")

        # Merge dotconfig with fragments
        kconfig_merge_fragments(${KCONFIG_MERGED_KCONFIG_PATH} ${defconfig_tmp} ${KCONFIG_DEFCONFIG})

        message(STATUS "Using defconfig: ${KCONFIG_DEFCONFIG}")
        kconfig_defconfig(
            "${KCONFIG_MERGED_KCONFIG_PATH}"
            "${defconfig_tmp}"
            "${KCONFIG_DOTCONFIG_PATH}"
            "${KCONFIG_AUTOHEADER_PATH}"
            "${KCONFIG_AUTOCONFIG_PATH}"
            "${KCONFIG_TRISTATE_PATH}"
        )
    endif()


    # Use tmp paths for .config and autoheader to prevent recompiling targets
    set(dotconfig_tmp "${KCONFIG_BINARY_TMP_DIR}/.config")
    set(autoheader_tmp "${KCONFIG_BINARY_TMP_DIR}/config_h")
    file(COPY_FILE ${KCONFIG_DOTCONFIG_PATH} ${dotconfig_tmp})

    # Generate config headers
    kconfig_genconfig(
        "${KCONFIG_MERGED_KCONFIG_PATH}"
        "${dotconfig_tmp}"
        "${autoheader_tmp}"
        "${KCONFIG_AUTOCONFIG_PATH}"
        "${KCONFIG_TRISTATE_PATH}"
    )

    # reimport dotconfig file
    kconfig_import_config("${KCONFIG_CONFIG_PREFIX}" "${KCONFIG_DOTCONFIG_PATH}" KCONFIG_KEYS ON)

    # Update .config and autoheader if new files are different
    file(COPY_FILE ${dotconfig_tmp} ${KCONFIG_DOTCONFIG_PATH} ONLY_IF_DIFFERENT)
    file(COPY_FILE ${autoheader_tmp} ${KCONFIG_AUTOHEADER_PATH} ONLY_IF_DIFFERENT)

    # Configure targets
    __kconfig_configure_targets(KCONFIG_KEYS)

    # print configs
    kconfig_print_configs()
    kconfig_set_global_properties()
endmacro()

# Add deferred call to __kconfig_post_configure
cmake_language(DEFER CALL __kconfig_post_configure)
