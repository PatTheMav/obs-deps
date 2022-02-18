[CmdletBinding()]
param(
    [ValidateSet('x86', 'x64')]
    [string] $Target,
    [ValidateSet('Debug', 'RelWithDebInfo', 'Release', 'MinSizeRel')]
    [string] $Configuration = 'Release',
    [string[]] $Dependencies,
    [switch] $SkipAll,
    [switch] $SkipDeps,
    [switch] $SkipUnpack,
    [switch] $SkipBuild,
    [switch] $Shared,
    [switch] $Clean,
    [switch] $Quiet
)

$ErrorActionPreference = "Stop"

if ( $DebugPreference -eq "Continue" ) {
    $VerbosePreference = "Continue"
    $InformationPreference = "Continue"
}

function Run-Stages {
    $Stages = @('Setup')

    if ( ( $script:SkipAll.isPresent ) -or ( $script:SkipBuild.isPresent ) ) {
        $Stages += @('Install', 'Fixup')
    } else {
        if (( $script:Clean.isPresent ) ) {
            $Stages += 'Clean'
        }
        $Stages += @(
            'Patch'
            'Configure'
            'Build'
            'Install'
            'Fixup'
        )
    }

    Log-Debug $DependencyFiles

    $DependencyFiles | Sort | ForEach-Object {
        $Dependency = $_

        $Version = 0
        $Uri = ''
        $Hash = ''
        $Path = ''
        $Versions = @()
        $Hashes = @()
        $Uris = @()
        $Patches = @()
        $Options = @{}
        $Targets = @($script:Target)

        . $Dependency

        if ( ! ( $Targets.contains($Target) ) ) { continue }

        if ( $Version -eq '' ) { $Version = $Versions[$Target] }
        if ( $Uri -eq '' ) { $Uri = $Uris[$Target] }
        if ( $Hash -eq '' ) { $Hash = $Hashes[$Target] }

        if ( $Path -eq '' ) { $Path = [System.IO.Path]::GetFileNameWithoutExtension($Uri) }

        Log-Output 'Initializing build'

        $Stages | ForEach-Object {
            $Stage = $_
            $script:StageName = $Name
            try {
                Push-Location -Stack BuildTemp
                if ( Test-Path function:$Stage ) {
                    . $Stage
                }
            } catch {
                Pop-Location -Stack BuildTemp
                Log-Error "Error during build step ${Stage} - $_"
            } finally {
                $StageName = ''
                Pop-Location -Stack BuildTemp
            }
        }

        $Stages | ForEach-Object {
            Log-Debug "Removing function $_"
            Remove-Item -ErrorAction 'SilentlyContinue' function:$_
            $script:StageName = ''
        }
    }

}

function Package-Dependencies {
    $ArchiveFileName = "windows-${PackageName}-${CurrentDate}-${Target}.zip"

    Push-Location -Stack BuildTemp
    Set-Location $ConfigData.OutputPath

    Log-Information "Cleanup dependencies"
    Remove-Item -ErrorAction 'SilentlyContinue' -Recurse -Force "$($ConfigData.OutputPath)/lib/"

    Log-Information "Package dependencies"

    $Params = @{
        Path = (Get-ChildItem -Path $(Get-Location))
        DestinationPath = $ArchiveFileName
        CompressionLevel = "Optimal"
    }

    Log-Information "Create archive ${ArchiveFileName}"
    Compress-Archive @Params

    Move-Item -Force -Path $ArchiveFileName -Destination ..

    Pop-Location -Stack BuildTemp
}

function Build-Main {
    trap {
        Write-Host '---------------------------------------------------------------------------------------------------'
        Write-Host -NoNewLine '[OBS-DEPS] '
        Write-Host -ForegroundColor Red 'Error(s) occurred:'
        Write-Host '---------------------------------------------------------------------------------------------------'
        Write-Error $_
        exit 2
    }

    $script:PackageName = 'deps'

    $UtilityFunctions = Get-ChildItem -Path $PSScriptRoot/utils.pwsh/*.ps1 -Recurse

    foreach($Utility in $UtilityFunctions) {
        Write-Debug "Loading $($Utility.FullName)"
        . $Utility.FullName
    }

    Bootstrap

    if ( $Dependencies.Count -eq 0 ) {
        $DependencyFiles = Get-ChildItem -Path $PSScriptRoot/${PackageName}.windows/*.ps1 -File -Recurse
    } else {
        $DependencyFiles = $Dependencies | ForEach-Object {
            $Item = $_
            try {
                Get-ChildItem $PSScriptRoot/deps.windows/*$Item.ps1
            } catch {
                throw "Script for requested dependency ${Item} not found"
            }
        }
    }

    Log-Debug "Using found dependency scripts:`n${DependencyFiles}"

    Push-Location -Stack BuildTemp

    Ensure-Location $WorkRoot

    Run-Stages

    Pop-Location -Stack BuildTemp

    if ( $Dependencies.Count -eq 0 ) {
        Package-Dependencies
    }

    Write-Host '---------------------------------------------------------------------------------------------------'
    Write-Host -NoNewLine '[OBS-DEPS] '
    Write-Host -ForegroundColor Green 'All done'
    Write-Host "Built Dependencies: $(if ( $script:Dependencies -eq $null ) { 'All' } else { $script:Dependencies })"
    Write-Host '---------------------------------------------------------------------------------------------------'
}

Build-Main
