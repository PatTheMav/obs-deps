autoload -Uz log_debug log_error log_info log_status log_output

name='ntv2'
version='16.1'
url='https://github.com/aja-video/ntv2.git'
hash='abf17cc1e7aadd9f3e4972774a3aba2812c51b75'
local -i force_static=1

setup() {
  log_info "Setup (%F{3}${target}%f)"
  setup_dep ${url} ${hash}
}

clean() {
  cd "${dir}"

  if [[ ${clean_build} -gt 0 && -d "build_${arch}" ]] {
    log_info "Clean build directory (%F{3}${target}%f)"

    rm -rf "build_${arch}"
  }
}

config() {
  autoload -Uz mkcd

  log_info "Config (%F{3}${target}%f)"

  if (( shared_libs )) {
    local shared=$(( shared_libs - force_static ))
  } else {
    local shared=0
  }
  local _onoff=(OFF ON)

  args=(
    ${cmake_flags}
    -DAJA_BUILD_OPENSOURCE=ON
    -DAJA_BUILD_SHARED="${_onoff[(( shared + 1 ))]}"
  )

  cd "${dir}"
  log_debug "CMake configure options: ${args}"
  progress cmake -S . -B "build_${arch}" -G Ninja ${args}
}

build() {
  autoload -Uz mkcd

  log_info "Build (%F{3}${target}%f)"

  cd "${dir}"
  cmake --build "build_${arch}" --config "${config}"
}

install() {
  autoload -Uz progress

  log_info "Install (%F{3}${target}%f)"

  args=(
    --install "build_${arch}"
    --config "${config}"
  )

  if [[ "${config}" =~ "Release|MinSizeRel" ]] args+=(--strip)

  cd "${dir}"
  progress cmake ${args}
}
