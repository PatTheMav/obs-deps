param(
    [string] $Name = 'libtheora',
    [string] $Version = '1.1.1',
    [string] $Uri = 'https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.1.1.zip',
    [string] $Hash = "${PSScriptRoot}/checksums/libtheora-1.1.1.zip.sha256",
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/libtheora/0001-add-windows-cmake.patch"
            HashSum = "f3e0608567c584bbdba6989663e0f8685248e34a7f064f573e418cf4833cc5b3"
        }
    ),
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
        "-DCMAKE_C_FLAGS=-wd4700"
    )

    Invoke-External cmake -S . -B "build_${Target}" @Options
}

function Build {
    Log-Information "Install (${Target})"
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
