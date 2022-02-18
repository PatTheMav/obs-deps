param(
    [string] $Name = 'VulkanSDK',
    [System.Version] $Version = '1.2.131.2',
    [string] $Uri = 'https://cdn-fastly.obsproject.com/downloads/VulkanSDK-1.2.131.2-Installer-Components.7z',
    [string] $Hash = "${PSScriptRoot}/checksums/VulkanSDK-1.2.131.2-Installer-Components.7z.sha256"
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    $Items = @(
        @{
            Path = "include/vulkan"
            Destination = "$($ConfigData.OutputPath)/include"
            Recurse = $true
        }
        @{
            Path = "lib$(if ( $Target -eq "x86" ) { "32" })/vulkan-1.lib"
            Destination = "$($ConfigData.OutputPath)/bin"
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Output ('{0} => {1}' -f ($Item.Path -join ", "), $Item.Destination)
        Copy-Item @Item
    }
}
