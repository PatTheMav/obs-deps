param(
    [string] $Name = 'curl',
    [string] $Version = '8.12.1',
    [string] $Uri = 'https://github.com/curl/curl.git',
    [string] $Hash = '57495c64871d18905a0941db9196ef90bafe9a29',
    [array] $Targets = @('x64', 'arm64')
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
}

function Clean {
    Set-Location $Path

    if ( Test-Path "build_${Target}" ) {
        Log-Information "Clean build directory (${Target})"
        Remove-Item -Path "build_${Target}" -Recurse -Force
    }
}

function Patch {
    Log-Information "Patch (${Target})"
    Set-Location $Path

    $Patches | ForEach-Object {
        $Params = $_
        Safe-Patch @Params
    }
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $Options = @(
        $CmakeOptions
        '-DBUILD_CURL_EXE:BOOL=OFF'
        '-DBUILD_TESTING:BOOL=OFF'
        '-DCURL_USE_LIBPSL=OFF'
        '-DCURL_USE_LIBSSH2:BOOL=OFF'
        '-DCURL_USE_SCHANNEL:BOOL=ON'
        '-DCURL_ZLIB:BOOL=OFF'
    )

    Invoke-External cmake -S . -B "build_${Target}" @Options
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    $Options = @(
        '--build', "build_${Target}"
        '--config', $Configuration
    )

    if ( $VerbosePreference -eq 'Continue' ) {
        $Options += '--verbose'
    }

    Invoke-External cmake @Options
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    $Options = @(
        '--install', "build_${Target}"
        '--config', $Configuration
    )

    if ( $Configuration -match "(Release|MinSizeRel)" ) {
        $Options += '--strip'
    }

    Invoke-External cmake @Options
}

function Fixup {
    Log-Information "Fixup (${Target})"
    Set-Location $Path

    Remove-Item -ErrorAction 'SilentlyContinue' "$($ConfigData.OutputPath)/bin/curl-config"
}
