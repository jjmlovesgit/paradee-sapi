param(
    [ValidateSet('CurrentUser', 'LocalMachine')]
    [string] $Scope = 'CurrentUser',
    [switch] $Uninstall
)

$ErrorActionPreference = 'Stop'
$clsid = '{14A9D4B6-B47D-46FB-B319-6067CAFB2AD9}'
$tokenName = 'ParadeeSapiBmFable'
$registryRoot = if ($Scope -eq 'LocalMachine') { 'Registry::HKEY_LOCAL_MACHINE' } else { 'Registry::HKEY_CURRENT_USER' }
$clsidKey = "$registryRoot\SOFTWARE\Classes\CLSID\$clsid"
$voiceKey = "$registryRoot\SOFTWARE\Microsoft\Speech\Voices\Tokens\$tokenName"
$oneCoreKey = "$registryRoot\SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\$tokenName"

if ($Scope -eq 'LocalMachine' -and -not $Uninstall) {
    throw 'Machine-wide development registration from a writable checkout is disabled. Build and run the Windows installer instead.'
}

if ($Scope -eq 'LocalMachine') {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'LocalMachine registration requires an elevated PowerShell session.'
    }
}

if ($Uninstall) {
    if ($Scope -eq 'LocalMachine' -and (Test-Path -LiteralPath $oneCoreKey)) {
        $registeredClsid = (Get-ItemProperty -LiteralPath $oneCoreKey -Name CLSID -ErrorAction Stop).CLSID
        if ($registeredClsid -ne $clsid) { throw 'OneCore token belongs to another engine; refusing removal.' }
        Remove-Item -LiteralPath $oneCoreKey -Recurse -Force
    }
    if (Test-Path -LiteralPath $voiceKey) {
        $registeredClsid = (Get-ItemProperty -LiteralPath $voiceKey -Name CLSID -ErrorAction Stop).CLSID
        if ($registeredClsid -ne $clsid) { throw 'Voice token belongs to another engine; refusing removal.' }
        Remove-Item -LiteralPath $voiceKey -Recurse -Force
    }
    if (Test-Path -LiteralPath $clsidKey) {
        Remove-Item -LiteralPath $clsidKey -Recurse -Force
    }
    Write-Host "Removed $tokenName ($Scope)"
    return
}

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dll = Join-Path $repo 'build\sapi5_bridge\paradee_sapi_bridge.dll'
$assets = Join-Path $repo 'build\native\assets'
if (-not (Test-Path -LiteralPath $dll)) { throw "Build the bridge first: $dll" }
if (-not (Test-Path -LiteralPath (Join-Path $assets 'paradee_int8.onnx'))) { throw "Native assets missing: $assets" }

New-Item -Path "$clsidKey\InprocServer32" -Force | Out-Null
Set-Item -LiteralPath $clsidKey -Value 'Paradee SAPI5 Local Bridge'
Set-Item -LiteralPath "$clsidKey\InprocServer32" -Value $dll
New-ItemProperty -LiteralPath "$clsidKey\InprocServer32" -Name ThreadingModel -Value Both -PropertyType String -Force | Out-Null

New-Item -Path "$voiceKey\Attributes" -Force | Out-Null
Set-Item -LiteralPath $voiceKey -Value 'Paradee bm_fable'
New-ItemProperty -LiteralPath $voiceKey -Name CLSID -Value $clsid -PropertyType String -Force | Out-Null
New-ItemProperty -LiteralPath $voiceKey -Name '809' -Value 'Paradee bm_fable' -PropertyType String -Force | Out-Null
New-ItemProperty -LiteralPath $voiceKey -Name VoiceName -Value bm_fable -PropertyType String -Force | Out-Null
New-ItemProperty -LiteralPath $voiceKey -Name AssetsDir -Value $assets -PropertyType String -Force | Out-Null
$attrs = @{
    Name = 'Paradee bm_fable'
    VoiceName = 'Paradee bm_fable'
    Language = '0809'
    Gender = 'Male'
    Age = 'Adult'
    Vendor = 'Paradee-SAPI'
    VoiceId = 'bm_fable'
    AssetsDir = $assets
    Rate = '1.0'
}
Remove-ItemProperty -LiteralPath "$voiceKey\Attributes" -Name Endpoint,Path,TimeoutMs -ErrorAction SilentlyContinue
foreach ($key in $attrs.Keys) {
    New-ItemProperty -LiteralPath "$voiceKey\Attributes" -Name $key -Value $attrs[$key] -PropertyType String -Force | Out-Null
}
if ($Scope -eq 'LocalMachine') {
    New-Item -Path "$oneCoreKey\Attributes" -Force | Out-Null
    Set-Item -LiteralPath $oneCoreKey -Value 'Paradee bm_fable'
    New-ItemProperty -LiteralPath $oneCoreKey -Name CLSID -Value $clsid -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $oneCoreKey -Name VoiceName -Value bm_fable -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $oneCoreKey -Name AssetsDir -Value $assets -PropertyType String -Force | Out-Null
    foreach ($key in $attrs.Keys) {
        New-ItemProperty -LiteralPath "$oneCoreKey\Attributes" -Name $key -Value $attrs[$key] -PropertyType String -Force | Out-Null
    }
}
Write-Host "Registered Paradee bm_fable ($Scope)"
Write-Host "Token: $voiceKey"
if ($Scope -eq 'LocalMachine') { Write-Host "OneCore token: $oneCoreKey" }
