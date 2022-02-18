function Expand-ArchiveExt {
    <#
        .SYNOPSIS
            Expands archives of wide support of file formats
        .DESCRIPTION
            Allows extraction of zip archives, as well as 7z, gz and xz archives.
            Requires tar and 7-zip to be available on the system.
            Archives ending with .zip but created using LZMA compression are
            expanded using 7-zip as a fallback
        .EXAMPLE
            Expand-ArchiveExt -Path <Path-To-Your-Archive>
            Expand-ArchiveExt -Path <Path-To-Your-Archive> -DestinationPath <Expansion-Path>
    #>

    param(
        [Parameter(Mandatory)]
        [string] $Path,
        [string] $DestinationPath = [System.IO.Path]::GetFileNameWithoutExtension($Path),
        [switch] $Force
    )

    switch ( [System.IO.Path]::GetExtension($Path) ) {
        .zip {
            try {
                Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force:$Force
            } catch {
                if ( Get-Command 7z ) {
                    Invoke-External 7z x -y $Path "-o${DestinationPath}"
                } else {
                    throw "Fallback utility 7-zip not found - please install 7-zip first"
                }
            }
            break
        }
        .7z {
            if ( Get-Command 7z ) {
                Invoke-External 7z x -y $Path "-o${DestinationPath}"
            } else {
                throw "Extraction utility 7-zip not found - please install 7-zip first"
            }
            break
        }
        .gz {
            Invoke-External tar -x -o $DestinationPath -f $Path
            break
        }
        .xz {
            Invoke-External tar -x -o $DestinationPath -f $Path
            break
        }
        default {
            throw "Unsupported archive extension provided"
        }
    }
}
