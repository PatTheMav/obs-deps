param(
    [string] $Name = 'curl',
    [System.Version] $Version = '7.73.0',
    [string] $Uri = 'https://github.com/curl/curl.git',
    [string] $Hash = '315ee3fe75dade912b48a21ceec9ccda0230d937'
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
        '-DBUILD_CURL_EXE=OFF'
        '-DBUILD_TESTING=OFF'
        '-DCMAKE_USE_LIBSSH2=OFF'
        '-DCMAKE_USE_SCHANNEL=ON'
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
            Path = "$($ConfigData.OutputPath)/lib/libcurl_imp.lib"
            Destination = "$($ConfigData.OutputPath)/bin/libcurl.lib"
            Force = $true
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Output ('{0} => {1}' -f ($Item.Path -join ", "), $Item.Destination)
        Move-Item @Item
    }

    Remove-Item -ErrorAction 'SilentlyContinue' "$($ConfigData.OutputPath)/bin/curl-config"
    Remove-Item -ErrorAction 'SilentlyContinue' -Recurse "$($ConfigData.OutputPath)/lib/cmake/CURL"
    Remove-Item -ErrorAction 'SilentlyContinue' -Recurse "$($ConfigData.OutputPath)/lib/pkgconfig/libcurl.pc"
}
