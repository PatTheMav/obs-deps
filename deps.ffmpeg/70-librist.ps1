param(
    [string] $Name = 'librist',
    [string] $Version = '0.2.7',
    [string] $Uri = 'https://code.videolan.org/rist/librist.git',
    [string] $Hash = "809390b3b75a259a704079d0fb4d8f1b5f7fa956",
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/librist/0001-generate-cross-compile-files-windows-native.patch"
            HashSum = "41f3cfdc082882d339b572a12432229d96fc0509d03ae9ddaccf394c61b1b62e"
        }
    ),
    [array] $Targets = @('x64'),
    [switch] $ForceShared = $true
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

   if ( $ForceShared -and ( ! $script:Shared ) ) {
        $Shared = $true
    } else {
        $Shared = $script:Shared.isPresent
    }

    $ConfigStrings = @{
        Debug = 'debug'
        RelWithDebInfo = 'debugoptimized'
        Release = 'release'
        MinSizeRel = 'minsize'
    }

    $VisualStudioData = Find-VisualStudio
    $VisualStudioId = ($VisualStudioData.DisplayName -split ' ')[3]

    $Options = @(
        '--buildtype', "$($ConfigStrings[$Configuration])"
        '--backend', "vs${VisualStudioId}"
        '--prefix', "$($script:ConfigData.OutputPath)"
        '--cross-file', "windows-${Target}.txt"
        '-Duse_mbedtls=true'
        '-Dbuiltin_cjson=true'
        '-Dbuiltin_mbedtls=true'
        '-Dtest=false'
        '-Dbuilt_tools=false'
    )

    if ( $Shared ) {
        $Options += @(
            '--default-library', 'both'
        )
    } else {
        $Options += @(
            '--default-library', 'static'
        )
    }

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = '.'
        BuildCommand = "meson setup build_${Target} $($Options -join ' ')"
        Target = $Target
    }

    Invoke-DevShell @Params
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = '.'
        BuildCommand = "meson compile -C build_${Target}"
        Target = $Target
    }

    Invoke-DevShell @Params
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    Invoke-External meson install -C "build_${Target}"
}

function Fixup {
    Log-Information "Fixup (${Target})"
    Set-Location $Path

    $Items = @(
        @{
            Path = "$($ConfigData.OutputPath)/lib/librist.lib"
            Destination = "$($ConfigData.OutputPath)/lib/rist.lib"
            Force = $true
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Output ('{0} => {1}' -f ($Item.Path -join ", "), $Item.Destination)
        Move-Item @Item
    }
}
