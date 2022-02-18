autoload -Uz log_debug log_error log_info log_status log_output

## Dependency Information
name='nv-codec-headers'
version='11.1.5.0'
url='https://github.com/ffmpeg/nv-codec-headers.git'
hash='e81e2ba5e8f365d47d91c8c8688769f62614b644'
targets=('windows-x*')

setup() {
  log_info "Setup (%F{3}${target}%f)"
  setup_dep ${url} ${hash}
}

build() {
  autoload -Uz mkcd progress

  log_info "Build (%F{3}${target}%f)"
  cd "${dir}"

  log_debug "Running make"
  make PREFIX="${target_config[output_dir]}"
}

install() {
  autoload -Uz progress

  log_info "Install (%F{3}${target}%f)"

  cd "${dir}"

  make PREFIX="${target_config[output_dir]}" install
}
