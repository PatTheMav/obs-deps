param(
    [string] $Name = 'svt-av1',
    [string] $Version = '1.4.1',
    [string] $Uri = 'https://gitlab.com/AOMediaCodec/SVT-AV1.git',
    [string] $Hash = '018276d714ce65d9b586f6205ee016cbd8d5425d',
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/svt-av1/0001-cpuinfo-MSVC-detection.patch"
            HashSum = "12eeb231e29c31fdcc1358aa207ec373e7ea2cd6700a2c3fd280cf5957b13c36"
        }
    ),
    [array] $Targets = @('x64')
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path

    if ( ! ( $SkipAll -or $SkipDeps ) ) {
        Invoke-External pacman.exe -S --noconfirm --needed --noprogressbar nasm
    }
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

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        "-DBUILD_SHARED_LIBS:BOOL=$($OnOff[$script:Shared.isPresent])"
        '-DBUILD_APPS:BOOL=OFF'
        '-DBUILD_DEC:BOOL=ON'
        '-DBUILD_ENC=ON'
        '-DENABLE_NASM:BOOL=ON'
        '-DBUILD_TESTING:BOOL=OFF'
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
