param([string]$Tag='v0.2.0')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$apk=Join-Path $projectRoot ('build/android/unnamed-fantasy-'+$Tag+'.apk')
$checksums=Join-Path $projectRoot 'build/android/SHA256SUMS.txt'
if (-not (Test-Path -LiteralPath $apk) -or -not (Test-Path -LiteralPath $checksums)) { throw 'Verified APK and checksums are required.' }
$repo='kurtreonal/Unnamed-Fantasy-A-Promise-Kept'
$env:GIT_TERMINAL_PROMPT='0'; $env:GCM_INTERACTIVE='Never'
$credentialLines="protocol=https`nhost=github.com`nusername=kurtreonal`n`n" | git credential fill
$token=($credentialLines | Where-Object { $_.StartsWith('password=') } | Select-Object -First 1).Substring(9)
$headers=@{Authorization=('Bearer '+$token);Accept='application/vnd.github+json';'X-GitHub-Api-Version'='2022-11-28'}
try {
    $commit=(git rev-parse HEAD).Trim()
    [string]$body=[IO.File]::ReadAllText((Join-Path $projectRoot '.godot/redesign-release-notes.md'),[Text.Encoding]::UTF8)
    try { $release=Invoke-RestMethod -Uri ('https://api.github.com/repos/'+$repo+'/releases/tags/'+$Tag) -Headers $headers }
    catch { if ([int]$_.Exception.Response.StatusCode -ne 404) { throw }; $release=$null }
    if ($release -and -not $release.draft) { throw 'This release is already public; do not overwrite it automatically.' }
    if (-not $release) {
        $payload=@{tag_name=$Tag;target_commitish=$commit;name=('A Promise Kept '+$Tag+' - Story and Gameplay Redesign');body=$body;draft=$true;prerelease=$true} | ConvertTo-Json
        if (-not (($payload | ConvertFrom-Json).body -is [string])) { throw 'Release notes must serialize as a plain string.' }
        $release=Invoke-RestMethod -Method Post -Uri ('https://api.github.com/repos/'+$repo+'/releases') -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($payload))
    }
    foreach ($file in @($apk,$checksums)) {
        $name=[IO.Path]::GetFileName($file)
        if ($release.assets.name -contains $name) { throw ('Draft already contains '+$name+'; inspect before replacing.') }
        $uploadUrl=$release.upload_url.Split('{')[0]+'?name='+[uri]::EscapeDataString($name)
        $asset=Invoke-RestMethod -Method Post -Uri $uploadUrl -Headers $headers -ContentType 'application/octet-stream' -InFile $file
        $localHash=(Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLower()
        if ($asset.size -ne (Get-Item -LiteralPath $file).Length -or $asset.digest -ne ('sha256:'+$localHash)) { throw 'Uploaded asset verification failed.' }
        Write-Output ('Verified uploaded asset '+$name)
    }
    $published=Invoke-RestMethod -Method Patch -Uri ('https://api.github.com/repos/'+$repo+'/releases/'+$release.id) -Headers $headers -ContentType 'application/json' -Body '{"draft":false}'
    Write-Output $published.html_url
} finally {
    $headers.Clear();$token=$null;$credentialLines=$null
}
