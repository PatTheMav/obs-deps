param(
    [string] $Name = 'cmocka',
    [System.Version] $Version = '1.1.5',
    [string] $Uri = 'https://git.cryptomilk.org/projects/cmocka.git',
    [string] $Hash = '9c114ac31a33217cf003bbb674c1aff7bb048917'
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

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        "-DBUILD_SHARED_LIBS=$($OnOff[$script:Shared.isPresent])"
        '-DBUILD_TESTING=OFF'
        '-DWITH_EXAMPLES=OFF'
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
            Path = "$($ConfigData.OutputPath)/lib/cmocka.lib"
            Destination = "$($ConfigData.OutputPath)/bin"
            Force = $true
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Output ('{0} => {1}' -f ($Item.Path -join ", "), $Item.Destination)
        Move-Item @Item
    }

    Remove-Item -ErrorAction 'SilentlyContinue' -Recurse "$($ConfigData.OutputPath)/lib/cmake/cmocka"
    Remove-Item -ErrorAction 'SilentlyContinue' -Recurse "$($ConfigData.OutputPath)/lib/pkgconfig/cmocka.pc"
}
