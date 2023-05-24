param(
    [string] $Name = 'libpng',
    [string] $Version = '1.6.39',
    [string] $Uri = 'https://sourceforge.net/projects/libpng/files/libpng16/1.6.39/lpng1639.zip',
    [string] $Hash = "${PSScriptRoot}/checksums/lpng1639.zip.sha256",
    [array] $Targets = @('x64')
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath .
}

function Clean {
    Set-Location $Path
    if ( Test-Path "build_${Target}" ) {
        Log-Information "Clean build directory (${Target})"
        Remove-Item -Path "build_${Target}" -Recurse -Force
    }
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        '-DPNG_TESTS=OFF'
        '-DPNG_STATIC=ON'
        "-DPNG_SHARED=$($OnOff[$script:Shared.isPresent])"
    )

    if ( $Configuration -eq 'Debug' ) {
        $Options += '-DPNG_DEBUG=ON'
    } else {
        $Options += '-DPNG_DEBUG=OFF'
    }

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

    $Options += @(
        '--'
        '/consoleLoggerParameters:Summary'
        '/noLogo'
        '/p:UseMultiToolTask=true'
        '/p:EnforceProcessCountAcrossBuilds=true'
    )

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
