param([ValidateSet('Web','Android')][string]$Platform='Web')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
if (Test-Path -LiteralPath 'override.cfg') { throw 'Remove the test override before exporting.' }
$engine='C:\Users\kupal\Desktop\Godot_v4.6.2-stable_win64.exe'
$log=Join-Path $projectRoot ('.godot/redesign-export-'+$Platform.ToLower()+'.log')
$output=if ($Platform -eq 'Web') { 'build/redesign-web/index.html' } else { 'build/android/unnamed-fantasy-v0.2.0.apk' }
New-Item -ItemType Directory -Path (Split-Path $output -Parent) -Force | Out-Null
try {
    if ($Platform -eq 'Android') {
        $credentials=Get-Content -Raw -LiteralPath '.private/android-signing/credentials.json' | ConvertFrom-Json
        $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH=(Resolve-Path -LiteralPath '.private/android-signing/unnamed-fantasy-release.p12').Path
        $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER=$credentials.alias
        $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$credentials.password
    }
    $export=Start-Process -FilePath $engine -ArgumentList '--headless','--path','.','--export-release',$Platform,$output,'--log-file',$log -WindowStyle Hidden -PassThru
    Write-Output ('Export process '+$export.Id)
    if (-not $export.WaitForExit(600000)) { Stop-Process -Id $export.Id; throw 'Export timed out.' }
    Get-Content -LiteralPath $log -Tail 20
    if ($export.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $output)) { throw 'Export failed.' }
    Get-Item -LiteralPath $output | Select-Object FullName,Length
} finally {
    Remove-Item Env:\GODOT_ANDROID_KEYSTORE_RELEASE_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:\GODOT_ANDROID_KEYSTORE_RELEASE_USER -ErrorAction SilentlyContinue
    Remove-Item Env:\GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    $credentials=$null
}
