param(
    [string] $Name = 'vlc',
    [string] $Version = '3.0.21',
    [string] $Uri = 'https://cdn-fastly.obsproject.com/downloads/vlc-3.0.21.zip',
    [string] $Hash = "${PSScriptRoot}/checksums/vlc-3.0.21.zip.sha256",
    [array] $Targets = @('x64', 'arm64')
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    $VersionString = [System.Version] $Version

    (Get-Content -Path include/vlc/libvlc_version.h.in -Raw) `
        -replace "@VERSION_MAJOR@", "$($VersionString.Major)" `
        -replace "@VERSION_MINOR@", "$($VersionString.Minor)" `
        -replace "@VERSION_REVISION@", "$($VersionString.Build)" `
        | Out-File -Path include/vlc/libvlc_version.h -NoNewLine
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    $Params = @{
        ErrorAction = "SilentlyContinue"
        Path = @(
            "$($ConfigData.OutputPath)/include"
        )
        ItemType = "Directory"
        Force = $true
    }

    New-Item @Params *> $null

    $Items = @(
        @{
            Path = "include/vlc"
            Destination = "$($ConfigData.OutputPath)/include/"
            Recurse = $true
            Force = $true
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Output ('{0} => {1}' -f ($Item.Path -join ", "), $Item.Destination)
        Copy-Item @Item
    }
}
