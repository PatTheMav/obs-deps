autoload -Uz log_debug log_error log_info log_status log_output dep_checkout

## Dependency Information
name='amf'
version='1.4.16.1'
url='https://github.com/GPUOpen-LibrariesAndSDKs/AMF.git'
hash='802f92ee52b9efa77bf0d3ea8bfaed6040cdd35e'
targets=('windows-x*')

setup() {
  log_info "Setup (%F{3}${target}%f)"
  mkcd ${dir}
  dep_checkout ${url} ${hash} --sparse -- set amf/public/include
}

install() {
  autoload -Uz progress

  log_info "Install (%F{3}${target}%f)"

  cd "${dir}"
  rsync -a amf/public/include/  "${target_config[output_dir]}/include/AMF"
}
