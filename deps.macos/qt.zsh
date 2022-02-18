autoload -Uz log_debug log_error log_info log_status log_output

## Dependency Information
name='qt'
version=5.15.2
url='https://download.qt.io/official_releases/qt/5.15/5.15.2/single/qt-everywhere-src-5.15.2.tar.xz'
hash="${0:a:h}/checksums/qt-everywhere-src-5.15.2.tar.xz.sha256"
local -a patches=(
  "macos ${0:a:h}/patches/Qt/0001-QTBUG-74606.patch \
    6ba73e94301505214b85e6014db23b042ae908f2439f0c18214e92644a356638"
  "macos ${0:a:h}/patches/Qt/0002-QTBUG-90370.patch \
    277b16f02f113e60579b07ad93c35154d7738a296e3bf3452182692b53d29b85"
  "macos ${0:a:h}/patches/Qt/0003-QTBUG-97855.patch \
    d8620262ad3f689fdfe6b6e277ddfdd3594db3de9dbc65810a871f142faa9966"
  "macos ${0:a:h}/patches/Qt/0004-fix-sdk-version-check.patch \
    391f4b8b26848cd4ad8f32d74f27ead4902711093b2897449ff7baa2906ee471"
)

setup() {
  if [[ ${shared_libs} -eq 0 && ${CPUTYPE} != "${arch}" ]] \
    { log_error "Cross compilation requires shared library build"; exit 2 }

  log_info "Setup (%F{3}${target}%f)"
  setup_dep ${url} ${hash}
}

clean() {
  cd "${dir}"

  if [[ ${clean_build} -gt 0 && -f "build_${arch}/Makefile" ]] {
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

    if [[ "${target%%-*}" == ${~_target} ]] apply_patch "${_url}" "${_hash}"
  }
}

config() {
  if [[ ${target} == 'macos-universal' ]] {
    universal_qt_config
    return
  }
  qt_config
}

qt_config() {
  autoload -Uz mkcd progress

  case ${config} {
    Debug) args+=(-debug) ;;
    RelWithDebInfo) args+=(-release -no-strip) ;;
    Release) args+=(-release -strip) ;;
    MinSizeRel) args+=(-release -optimize-size -strip) ;;
  }

  args+=(
    --prefix="${target_config[output_dir]}"
    -opensource
    -confirm-license
    -qt-libpng
    -qt-libjpeg
    -qt-freetype
    -qt-pcre
    -nomake examples
    -nomake tests
    -no-glib
    -system-zlib
    -no-webp
    -no-tiff
    -c++std c++17
    ${${commands[ccache]}:+-ccache}
  )

  if (( _loglevel > 1 )) {
    args+=(-verbose)
  } elif (( ! _loglevel )) {
    args+=(-silent)
  }

  if (( shared_libs )) {
    args+=(-shared -rpath)
  } else {
    args+=(-no-shared -static)
  }

  local part
  for part ('3d' 'activeqt' 'androidextras' 'charts' 'connectivity' 'datavis3d' 'declarative' 'doc'
    'gamepad' 'graphicaleffects' 'location' 'script' 'scxml' 'sensors' 'serialbus' 'speech'
    'translations' 'wayland' 'webchannel' 'webengine' 'webglplugin' 'websockets' 'webview'
    'winextras' 'x11extras' 'xmlpatterns') {
    args+=(-skip "qt${part}")
  }

  args+=(QMAKE_APPLE_DEVICE_ARCHS="${arch}")

  log_status "Hide undesired libraries from qt..."
  if [[ -d "${HOMEBREW_PREFIX}/opt/zstd" ]] brew unlink zstd

  log_info "Config (%F{3}${target}%f)"
  cd "${dir}"

  mkcd "build_${arch}"

  log_debug "Configure options: ${args}"
  ../configure ${args}
}

build() {
  autoload -Uz mkcd progress

  if [[ ${target} == 'macos-universal' ]] {
    universal_qt_build
    return
  }

  if [[ ${CPUTYPE} != "${arch}" ]] {
    cross_prepare
  }

  log_info "Build (%F{3}${target}%f)"
  cd "${dir}/build_${arch}"

  log_debug "Running make -j ${num_procs}"
  progress make -j "${num_procs}"
}

install() {
  autoload -Uz progress

  if [[ ${target} == 'macos-universal' ]] {
    universal_install
    universal_fixup
    return
  }

  cd "${dir}/build_${arch}"

  log_info "Install (%F{3}${target}%f)"
  progress make install

  if [[ ${CPUTYPE} != "${arch}" ]] {
    cp -cp qtbase/bin/qmake "${target_config[output_dir]}/bin/"

    for file (
      'lib/QtCore.framework/Versions/5/QtCore'
      'lib/libQt5Bootstrap.a'
      'bin/qvkgen'
      'bin/rcc'
      'bin/uic'
      'bin/qmake'
      'bin/qlalr'
    ) {
      lipo "${target_config[output_dir]}/${file}" \
        -thin ${arch} \
        -output "${target_config[output_dir]}/${file}"
    }
  }
}

fixup() {
  if [[ -d "${HOMEBREW_PREFIX}/opt/zstd" && ! -h "${HOMEBREW_PREFIX}/lib/libzstd.dylib" ]] brew link zstd
}

cross_prepare() {
  autoload -Uz progress

  pushd ${PWD}

  if [[ ! -f "${dir}/build_${CPUTYPE}/qtbase/lib/QtCore.framework/Versions/5/QtCore" ]] {
    log_status "Build QtCore (macos-${CPUTYPE})..."

    pushd ${PWD}
    (
      arch=${CPUTYPE}
      target="macos-${CPUTYPE}"
      args=()

      qt_config

      progress make -j ${num_procs} module-qtbase-qmake_all

      cd qtbase/src
      progress make -j ${num_procs} sub-moc-all
      progress make -j ${num_procs} sub-corelib
    )
    popd
  }

  cd "${dir}/build_${arch}"

  # qmake is built thin by the configure script
  if ! ([[ -f "qtbase/bin/qmake" ]] && \
    lipo -archs "qtbase/bin/qmake" | grep "${arch}" >/dev/null 2>&1); then
    pushd ${PWD}
    log_info "Fix qmake to enable building ${arch} on ${CPUTYPE} host"

    log_status "Apply patches to qmake makefile..."
    apply_patch "${funcfiletrace[1]:a:h}/patches/Qt/0005-qmake-append-cflags-and-ldflags.patch" \
      "4840e9104c2049228c307056d86e2d9f2464dedc761c02eb4494b602a3896ab6"

    log_status "Remove thin qmake"
    rm "qtbase/bin/qmake"
    cd "qtbase/qmake"
    progress make clean

    log_status "Build qmake..."
    EXTRA_LFLAGS="-arch arm64 -arch x86_64" \
    EXTRA_CXXFLAGS="-arch arm64 -arch x86_64" \
    progress make -j ${num_procs} qmake
    popd
  fi

  # we need to build some tools universal so we can cross compile on x86 host
  log_status "Build Qt build tools..."
  progress make -j ${num_procs} module-qtbase-qmake_all

  # Modify Makefiles so we can specify ARCHS
  local fixup
  for fixup (qtbase/src/**/Makefile) {
    log_status "Patching ${fixup}"
    sed -i '.orig' "s/EXPORT_VALID_ARCHS =/EXPORT_VALID_ARCHS +=/" ${fixup}
  }

  log_status "Build Qt tools (part 1)..."
  pushd ${PWD}
  cd "qtbase/src"
  ARCHS="arm64 x86_64" EXPORT_VALID_ARCHS="arm64 x86_64" progress make -j ${num_procs} sub-moc-all

  # QtCore sadly does not build universal so we build it for both archs, lipo them,
  # then continue building all of the other tools we need
  log_status "Build QtCore..."
  progress make -j ${num_procs} sub-corelib
  popd

  log_status "Create universal QtCore..."
  if lipo -archs "qtbase/lib/QtCore.framework/Versions/5/QtCore" \
    | grep "${CPUTYPE}" >/dev/null 2>&1; then
      log_info "Target architecture ${CPUTYPE} already found, will remove"
      lipo -remove ${CPUTYPE} "qtbase/lib/QtCore.framework/Versions/5/QtCore" \
        -output "qtbase/lib/QtCore.framework/Versions/5/QtCore"
  fi

  lipo -create "../build_${CPUTYPE}/qtbase/lib/QtCore.framework/Versions/5/QtCore" \
    "qtbase/lib/QtCore.framework/Versions/5/QtCore" \
    -output "qtbase/lib/QtCore.framework/Versions/5/QtCore"

  log_status "Build Qt tools (part 2)..."
  pushd ${PWD}
  cd "qtbase/src"
  ARCHS="arm64 x86_64" EXPORT_VALID_ARCHS="arm64 x86_64" \
    progress make -j ${num_procs} sub-qvkgen-all sub-rcc sub-uic sub-qlalr
  popd
  popd
}

universal_qt_config() {
  local a
  local -A other_arch=( arm64 x86_64 x86_64 arm64 )

  for a (${CPUTYPE} ${other_arch[${CPUTYPE}]}) {
    (
      arch="${a}"
      target="${target//universal/${a}}"
      args=()
      target_config=(${(kv)target_config//universal/${a}})
      qt_config
    )
  }
}

universal_qt_build() {
  local a
  local -A other_arch=( arm64 x86_64 x86_64 arm64 )

  for a (${CPUTYPE} ${other_arch[${CPUTYPE}]}) {
    (
      arch="${a}"
      target="${target//universal/${a}}"
      args=()
      target_config=(${(kv)target_config//universal/${a}})
      build
    )
  }
}

universal_install() {
  local a
  local -A other_arch=( arm64 x86_64 x86_64 arm64 )
  for a (${CPUTYPE} ${other_arch[${CPUTYPE}]}) {
    (
      arch="${a}"
      target="${target//universal/${a}}"
      target_config=(${(kv)target_config//universal/${a}})
      install
    )
  }
}

universal_fixup() {
  local file
  local magic

  log_status "Create universal binaries..."
  rm -rf "${target_config[output_dir]}"
  cp -cpR "${${target_config[output_dir]}//universal/arm64}" "${target_config[output_dir]}"
  cd ${target_config[output_dir]}

  # Using arm64 as the source build, find any file starting with magic bytes for thin binary

  local -a fixups=(lib/**/(*.a|*.dylib)(.) lib/**/*.framework/Versions/(5|6)/*(.))

  for file (bin/**/*(.)) {
    magic=$(xxd -ps -l 4 ${file})

    if [[ ${magic} == "cffaedfe" ]] fixups+=(${file})
  }

  for file (${fixups}) {
    log_status "Combining ${file}..."
    lipo -create \
      "${${target_config[output_dir]}//universal/arm64}/${file}" \
      "${${target_config[output_dir]}//universal/x86_64}/${file}" \
      -output ${file}
  }
}
