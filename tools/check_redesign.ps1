param([switch]$Runtime, [switch]$Integration, [switch]$Touch)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$override = Join-Path $projectRoot 'override.cfg'
if (Test-Path -LiteralPath $override) { throw 'An override.cfg already exists; preserve it before running isolated checks.' }
$identity = 'A Promise Kept Redesign Smoke ' + [Guid]::NewGuid().ToString('N')
try {
    [System.IO.File]::WriteAllText($override, "[application]`nconfig/name=`"$identity`"`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$identity`"`n", [System.Text.UTF8Encoding]::new($false))
    $checkArgs = @('--headless','--path',$projectRoot,'--quit-after','1800')
    if ($Runtime) { $checkArgs += @('--','--redesign-smoke') }
    elseif ($Integration) { $checkArgs += @('--script','tests/redesign_integration.gd') }
    elseif ($Touch) { $checkArgs += @('--script','tests/redesign_touch.gd','--','--touch-test') }
    else { $checkArgs += @('--script','tests/redesign_smoke.gd') }
    $log = Join-Path $projectRoot '.godot/redesign-check.log'
    $checkArgs = @('--log-file',$log) + $checkArgs
    $check = Start-Process -FilePath 'C:\Users\kupal\Desktop\Godot_v4.6.2-stable_win64.exe' -ArgumentList $checkArgs -WindowStyle Hidden -PassThru
    if (-not $check.WaitForExit(60000)) { Stop-Process -Id $check.Id; throw 'Godot check exceeded 60 seconds' }
    Get-Content -LiteralPath $log -Tail 65
    if ($check.ExitCode -ne 0 -or -not (Select-String -LiteralPath $log -Pattern 'PASS:' -Quiet)) { throw 'Redesign check did not pass' }
    $failures = Get-Content -LiteralPath $log | Where-Object { $_ -match 'SCRIPT ERROR:|^ERROR:' -and $_ -notmatch 'resources still in use|RID allocations' }
    if ($failures) { throw ('Runtime errors remain: ' + ($failures -join '; ')) }
} finally {
    Remove-Item -LiteralPath $override -ErrorAction SilentlyContinue
}
