param(
    [string] $Name = 'ntv2',
    [System.Version] $Version = '16.1',
    [string] $Uri = 'https://github.com/aja-video/ntv2.git',
    [string] $Hash = 'abf17cc1e7aadd9f3e4972774a3aba2812c51b75'
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

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        "-DAJA_BUILD_SHARED=$($OnOff[$script:Shared.isPresent])"
        '-DAJA_BUILD_OPENSOURCE=ON'
        '-DAJA_BUILD_QT_BASED=OFF'
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
    )

    if ( $Configuration -match "(Release|MinSizeRel)" ) {
        $Options += '--strip'
    }

    Invoke-External cmake @Options
}

function Fixup {
    Log-Information "Fixup (${Target})"

    Set-Location $Path

    if ( ! ( Test-Path "$($ConfigData.OutputPath)/bin" ) ) {
        New-Item -Type Directory -Path "$($ConfigData.OutputPath)/bin"
    }

    $Items = @(
        @{
            Path = "$($ConfigData.OutputPath)/lib/ajantv2.lib"
            Destination = "$($ConfigData.OutputPath)/bin"
            Force = $true
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Output ('{0} => {1}' -f ($Item.Path -join ", "), $Item.Destination)
        Move-Item @Item
    }
}
