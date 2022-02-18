function Invoke-External {
    <#
        .SYNOPSIS
            Invoke a non-Powershell command
        .DESCRIPTION
            Runs a non-powershell command, capturing its return code,
            throwing an exception if a non-zero return occurred.
        .EXAMPLE
            Invoke-External 7z x $MyArchive
    #>

    if ( $args.Count -eq 0 ) {
        throw "Invoke-External called without arguments"
    }

    if ( ! ( Test-Path function:Log-Information ) ) {
        . $PSScriptRoot/Utils-Logger.ps1
    }

    $Command = $args[0]
    $CommandArgs = @()

    if ( $args.Count -gt 1) {
        $CommandArgs = $args[1..($args.Count - 1)]
    }

    $_EAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    Log-Debug "Invoke-External: ${Command} ${CommandArgs}"

    & $command $commandArgs
    $Result = $LASTEXITCODE

    $ErrorActionPreference = $_EAP

    if ( $Result -ne 0 ) {
        throw "${Command} ${CommandArgs} exited with non-zero code ${Result}."
    }
}
