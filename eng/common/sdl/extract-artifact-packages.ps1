param(
  [Parameter(Mandatory=$true)][string] $InputPath,              # Full path to directory where artifact packages are stored
  [Parameter(Mandatory=$true)][string] $ExtractPath            # Full path to directory where the packages will be extracted
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
$ExtractPackage = {
  param( 
    [string] $PackagePath                                 # Full path to a NuGet package
  )
  
  if (!(Test-Path $PackagePath)) {
    Write-PipelineTaskError "Input file does not exist: $PackagePath"
    ExitWithExitCode 1
  }
  
  $RelevantExtensions = @(".dll", ".exe", ".pdb")
  Write-Host -NoNewLine "Extracting" ([System.IO.Path]::GetFileName($PackagePath)) "... "

  $PackageId = [System.IO.Path]::GetFileNameWithoutExtension($PackagePath)
  $ExtractPath = Join-Path -Path $using:ExtractPath -ChildPath $PackageId

  Add-Type -AssemblyName System.IO.Compression.FileSystem

  [System.IO.Directory]::CreateDirectory($ExtractPath);

  try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($PackagePath)

    $zip.Entries | 
    Where-Object {$RelevantExtensions -contains [System.IO.Path]::GetExtension($_.Name)} |
      ForEach-Object {
        $FileName = $_.FullName
          $Extension = [System.IO.Path]::GetExtension($_.Name)
          $FakeName = -Join((New-Guid), $Extension)
          $TargetFile = Join-Path -Path $ExtractPath -ChildPath $FakeName 

          # We ignore resource DLLs
          if ($FileName.EndsWith(".resources.dll")) {
            return
          }

          [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $TargetFile, $true)
        }

        }
  
  catch {
  
  }
  finally {
    $zip.Dispose() 
  }
 }
 function ExtractArtifacts {
  $Jobs = @()
  Get-ChildItem "$InputPath\*.nupkg" |
    ForEach-Object {
      $Jobs += Start-Job -ScriptBlock $ExtractPackage -ArgumentList $_.FullName
    }

  foreach ($Job in $Jobs) {
    Wait-Job -Id $Job.Id | Receive-Job
  }
}

try {
  Measure-Command { ExtractArtifacts }
}
catch {
  Write-Host $_
  Write-Host $_.Exception
  Write-Host $_.ScriptStackTrace
  ExitWithExitCode 1
}
