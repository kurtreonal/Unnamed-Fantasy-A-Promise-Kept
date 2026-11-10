$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
if (Test-Path -LiteralPath 'override.cfg') { throw 'An isolated test is still running.' }
$log=Join-Path $projectRoot '.godot/redesign-final-import.log'
$import=Start-Process -FilePath 'C:\Users\kupal\Desktop\Godot_v4.6.2-stable_win64.exe' -ArgumentList '--headless','--path','.','--editor','--import','--log-file',$log -WindowStyle Hidden -PassThru
Write-Output ('Import process '+$import.Id)
if (-not $import.WaitForExit(600000)) { Stop-Process -Id $import.Id; throw 'Import exceeded ten minutes.' }
Get-Content -LiteralPath $log -Tail 15
if ($import.ExitCode -ne 0) { throw 'Godot import failed.' }
$failures=Get-Content -LiteralPath $log | Where-Object { $_ -match 'SCRIPT ERROR:|^ERROR:' -and $_ -notmatch 'resources still in use|RID allocations' }
if ($failures) { throw ('Import errors remain: '+($failures -join '; ')) }
