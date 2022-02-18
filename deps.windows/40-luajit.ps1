param(
    [string] $Name = 'luajit',
    [System.Version] $Version = '2.0.5',
    [string] $Uri = 'https://github.com/luajit/luajit.git',
    [string] $Hash = '0bf80b07b0672ce874feedcc777afe1b791ccb5a'
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "src"
        BuildCommand = "cmd.exe /c 'msvcbuild.bat amalg'"
        Target = $Target
    }

    Invoke-DevShell @Params
}

function Install {
    Log-Information "Install (${Target})"

    Set-Location $Path

    $Params = @{
        Path = "$($ConfigData.OutputPath)/include/luajit"
        ItemType = "Directory"
        Force = $true
    }

    $null = New-Item @Params

    $Items = @(
        @{
            Path = "src/*.h"
            Destination = "$($ConfigData.OutputPath)/include/luajit"
        }
        @{
            Path = "src/lua51.dll", "src/lua51.lib"
            Destination = "$($ConfigData.OutputPath)/bin"
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Output ('{0} => {1}' -f ($Item.Path -join ", "), $Item.Destination)
        Copy-Item @Item
    }
}

function Fixup {
    Log-Information "Fixup (${Target})"

    Set-Location $Path

    if ( ! ( Test-Path "$($ConfigData.OutputPath)/bin" ) ) {
        New-Item -Type Directory -Path "$($ConfigData.OutputPath)/bin"
    }

    $Items = @(
        @{
            Path = "$($ConfigData.OutputPath)/bin/lua51.lib"
            Destination = "$($ConfigData.OutputPath)/bin/luajit.lib"
            Force = $true
        }
        @{
            Path = "$($ConfigData.OutputPath)/bin/lua51.dll"
            Destination = "$($ConfigData.OutputPath)/bin/luajit.dll"
            Force = $true
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Output ('{0} => {1}' -f ($Item.Path -join ", "), $Item.Destination)
        Move-Item @Item
    }
}
