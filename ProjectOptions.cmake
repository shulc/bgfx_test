include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(bgfx_test_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(bgfx_test_setup_options)
  option(bgfx_test_ENABLE_HARDENING "Enable hardening" ON)
  option(bgfx_test_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    bgfx_test_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    bgfx_test_ENABLE_HARDENING
    OFF)

  bgfx_test_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR bgfx_test_PACKAGING_MAINTAINER_MODE)
    option(bgfx_test_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(bgfx_test_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(bgfx_test_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(bgfx_test_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(bgfx_test_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(bgfx_test_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(bgfx_test_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(bgfx_test_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(bgfx_test_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(bgfx_test_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(bgfx_test_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(bgfx_test_ENABLE_PCH "Enable precompiled headers" OFF)
    option(bgfx_test_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(bgfx_test_ENABLE_IPO "Enable IPO/LTO" ON)
    option(bgfx_test_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(bgfx_test_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(bgfx_test_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(bgfx_test_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(bgfx_test_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(bgfx_test_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(bgfx_test_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(bgfx_test_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(bgfx_test_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(bgfx_test_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(bgfx_test_ENABLE_PCH "Enable precompiled headers" OFF)
    option(bgfx_test_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      bgfx_test_ENABLE_IPO
      bgfx_test_WARNINGS_AS_ERRORS
      bgfx_test_ENABLE_USER_LINKER
      bgfx_test_ENABLE_SANITIZER_ADDRESS
      bgfx_test_ENABLE_SANITIZER_LEAK
      bgfx_test_ENABLE_SANITIZER_UNDEFINED
      bgfx_test_ENABLE_SANITIZER_THREAD
      bgfx_test_ENABLE_SANITIZER_MEMORY
      bgfx_test_ENABLE_UNITY_BUILD
      bgfx_test_ENABLE_CLANG_TIDY
      bgfx_test_ENABLE_CPPCHECK
      bgfx_test_ENABLE_COVERAGE
      bgfx_test_ENABLE_PCH
      bgfx_test_ENABLE_CACHE)
  endif()

  bgfx_test_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (bgfx_test_ENABLE_SANITIZER_ADDRESS OR bgfx_test_ENABLE_SANITIZER_THREAD OR bgfx_test_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(bgfx_test_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(bgfx_test_global_options)
  if(bgfx_test_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    bgfx_test_enable_ipo()
  endif()

  bgfx_test_supports_sanitizers()

  if(bgfx_test_ENABLE_HARDENING AND bgfx_test_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR bgfx_test_ENABLE_SANITIZER_UNDEFINED
       OR bgfx_test_ENABLE_SANITIZER_ADDRESS
       OR bgfx_test_ENABLE_SANITIZER_THREAD
       OR bgfx_test_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${bgfx_test_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${bgfx_test_ENABLE_SANITIZER_UNDEFINED}")
    bgfx_test_enable_hardening(bgfx_test_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(bgfx_test_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(bgfx_test_warnings INTERFACE)
  add_library(bgfx_test_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  bgfx_test_set_project_warnings(
    bgfx_test_warnings
    ${bgfx_test_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(bgfx_test_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(bgfx_test_options)
  endif()

  include(cmake/Sanitizers.cmake)
  bgfx_test_enable_sanitizers(
    bgfx_test_options
    ${bgfx_test_ENABLE_SANITIZER_ADDRESS}
    ${bgfx_test_ENABLE_SANITIZER_LEAK}
    ${bgfx_test_ENABLE_SANITIZER_UNDEFINED}
    ${bgfx_test_ENABLE_SANITIZER_THREAD}
    ${bgfx_test_ENABLE_SANITIZER_MEMORY})

  set_target_properties(bgfx_test_options PROPERTIES UNITY_BUILD ${bgfx_test_ENABLE_UNITY_BUILD})

  if(bgfx_test_ENABLE_PCH)
    target_precompile_headers(
      bgfx_test_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(bgfx_test_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    bgfx_test_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(bgfx_test_ENABLE_CLANG_TIDY)
    bgfx_test_enable_clang_tidy(bgfx_test_options ${bgfx_test_WARNINGS_AS_ERRORS})
  endif()

  if(bgfx_test_ENABLE_CPPCHECK)
    bgfx_test_enable_cppcheck(${bgfx_test_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(bgfx_test_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    bgfx_test_enable_coverage(bgfx_test_options)
  endif()

  if(bgfx_test_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(bgfx_test_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(bgfx_test_ENABLE_HARDENING AND NOT bgfx_test_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR bgfx_test_ENABLE_SANITIZER_UNDEFINED
       OR bgfx_test_ENABLE_SANITIZER_ADDRESS
       OR bgfx_test_ENABLE_SANITIZER_THREAD
       OR bgfx_test_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    bgfx_test_enable_hardening(bgfx_test_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
