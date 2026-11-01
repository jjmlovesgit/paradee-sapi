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

if ($Scope -eq 'LocalMachine') {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'LocalMachine registration requires an elevated PowerShell session.'
    }
}

if ($Uninstall) {
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
if (-not (Test-Path -LiteralPath $dll)) { throw "Build the bridge first: $dll" }

New-Item -Path "$clsidKey\InprocServer32" -Force | Out-Null
Set-Item -LiteralPath $clsidKey -Value 'Paradee SAPI5 Local Bridge'
Set-Item -LiteralPath "$clsidKey\InprocServer32" -Value $dll
New-ItemProperty -LiteralPath "$clsidKey\InprocServer32" -Name ThreadingModel -Value Both -PropertyType String -Force | Out-Null

New-Item -Path "$voiceKey\Attributes" -Force | Out-Null
Set-Item -LiteralPath $voiceKey -Value 'Paradee bm_fable'
New-ItemProperty -LiteralPath $voiceKey -Name CLSID -Value $clsid -PropertyType String -Force | Out-Null
New-ItemProperty -LiteralPath $voiceKey -Name '809' -Value 'Paradee bm_fable' -PropertyType String -Force | Out-Null
$attrs = @{
    Name = 'Paradee bm_fable'
    VoiceName = 'Paradee bm_fable'
    Language = '0809'
    Gender = 'Male'
    Age = 'Adult'
    Vendor = 'Paradee-SAPI'
    Endpoint = 'http://127.0.0.1:5057'
    Path = '/v1/speech'
    VoiceId = 'bm_fable'
    Rate = '1.0'
    TimeoutMs = '30000'
}
foreach ($key in $attrs.Keys) {
    New-ItemProperty -LiteralPath "$voiceKey\Attributes" -Name $key -Value $attrs[$key] -PropertyType String -Force | Out-Null
}
Write-Host "Registered Paradee bm_fable ($Scope)"
Write-Host "Token: $voiceKey"
