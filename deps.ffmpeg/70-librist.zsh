autoload -Uz log_debug log_error log_info log_status log_output

## Dependency Information
name='librist'
local version='0.2.7'
local url='https://code.videolan.org/rist/librist.git'
local hash='419f09ea9aa9bf15f9c43b7752ca878521543679'
local -a patches=(
  "macos ${0:a:h}/patches/librist/0001-generate-cross-compile-files-macos.patch \
    e525ff5e29a623088c06da6c3e2b998e52653df7989dddec12f64afddaeaa93a"
  "windows ${0:a:h}/patches/librist/0001-generate-cross-compile-files-windows.patch \
    eb6e10a281960a47c61d61f1fb5fec0bbd59379cd67ee6727498e7cc02ed1e29"
)

setup() {
  log_info "Setup (%F{3}${target}%f)"
  setup_dep ${url} ${hash}
}

clean() {
  cd "${dir}"

  if [[ ${clean_build} -gt 0 && -f "build_${arch}/build.ninja" ]] {
    log_info "Clean build directory (%F{3}${target}%f)"

    rm -rf "build_${arch}"
  }
}

patch() {
  autoload -Uz apply_patch

  log_info "Patch (%F{3}${target}%f)"

  cd "${dir}"

  local patch
  local _target
  local _url
  local _hash

  for patch (${patches}) {
    read _target _url _hash <<< "${patch}"

    if [[ ${_target} == "${target%%-*}" ]] apply_patch "${_url}" "${_hash}"
  }
}

config() {
  autoload -Uz mkcd progress

  local build_type

  case ${config} {
    Debug) build_type='debug' ;;
    RelWithDebInfo) build_type='debugoptimized' ;;
    Release) build_type='release' ;;
    MinSizeRel) build_type='minsize' ;;
  }

  if (( shared_libs )) {
    args+=(--default-library both)
  } else {
    args+=(--default-library static)
  }

  case "${target}" {
    macos-universal)
      autoload -Uz universal_config && universal_config
      return
      ;;
    macos-*) args+=(--cross-file "cross_compile_${arch}.txt") ;;
    windows-x*)
      args+=(--cross-file "cross_mingw_${target_config[cmake_arch]}.txt")

      if (( shared_libs )) {
        args+=(-Dhave_mingw_pthreads=false)
      } else {
        args+=(-Dhave_mingw_pthreads=true)
      }
      ;;
  }

  log_info "Config (%F{3}${target}%f)"
  cd "${dir}"

  args+=(
    --buildtype "${build_type}"
    --prefix "${target_config[output_dir]}"
    -Duse_mbedtls=true
    -Dbuiltin_cjson=true
    -Dtest=false
    -Dbuilt_tools=false
    -Dpkg_config_path="${target_config[output_dir]}/lib/pkgconfig"
  )

  log_debug "Meson configure options: ${args}"
  meson setup "build_${arch}" ${args}
}

build() {
  autoload -Uz mkcd progress

  case ${target} {
    macos-universal)
      autoload -Uz universal_build && universal_build
      return
      ;;
  }

  log_info "Build (%F{3}${target}%f)"
  cd "${dir}"

  log_debug "Running meson compile -C build_${arch}"
  meson compile -C "build_${arch}"
}

install() {
  autoload -Uz progress

  log_info "Install (%F{3}${target}%f)"

  cd "${dir}"

  meson install -C "build_${arch}"
}

fixup() {
  cd "${dir}"

  if (( shared_libs )) {
    log_info "Fixup (%F{3}${target}%f)"
    case ${target} {
      macos*)
          autoload -Uz fix_rpaths
          fix_rpaths "${target_config[output_dir]}"/lib/librist*.dylib(.)

        strip_tool=strip
        strip_files=("${target_config[output_dir]}"/lib/librist*.dylib(.))
        ;;
      linux*)
        strip_tool=strip
        strip_files=("${target_config[output_dir]}"/lib/librist.so*(.))
        ;;
      windows-x*)
        autoload -Uz create_importlibs
        create_importlibs ${target_config[output_dir]}/bin/librist*.dll(.)

        strip_tool=${target_config[cross_prefix]}-w64-mingw32-strip
        strip_files=("${target_config[output_dir]}"/bin/librist*.dll(.))
        ;;
    }

    if [[ "${config}" == (Release|MinSizeRel) ]] {
      local file
      for file (${strip_files}(N)) {
        ${strip_tool} -x "${file}"
        log_status "Stripped ${file#"${target_config[output_dir]}"}"
      }
    }
  }
}
