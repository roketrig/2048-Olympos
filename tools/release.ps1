# Builds the signed release AAB for Google Play.
# Asks for the keystore password and keeps it only in memory for this run:
# it is never written to disk, the repo or the environment of other programs.
#
#   powershell -ExecutionPolicy Bypass -File tools\release.ps1

$ErrorActionPreference = "Stop"

$project = Split-Path -Parent $PSScriptRoot
$desktop = Split-Path -Parent $project
$godot = Join-Path $desktop "Godot_v4.7.2-stable_win64.exe"
$output = Join-Path $desktop "build\android\2048-olympos.aab"
$keystore = Join-Path $env:USERPROFILE "olympos2048-release.keystore"
$keytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"

if (-not (Test-Path $keystore)) { throw "Keystore not found: $keystore" }
if (-not (Test-Path $godot)) { throw "Godot not found: $godot" }

$secure = Read-Host "Keystore password (nothing shows while typing)" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)

$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keystore
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "olympos2048"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
try {
	if (Test-Path $output) { Remove-Item $output }
	Write-Host "Building release AAB, this takes a few minutes..."
	& $godot --headless --path $project --export-release "Android" $output
} finally {
	Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
	[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

if (-not (Test-Path $output)) {
	Write-Host "FAILED: no AAB was produced. Check the messages above (a wrong password is the usual cause)." -ForegroundColor Red
	exit 1
}

# The AAB must be signed with our upload key, not the debug key.
$cert = & $keytool -printcert -jarfile $output 2>&1 | Out-String
if ($cert -match "Bugra Kasarci") {
	$size = [math]::Round((Get-Item $output).Length / 1MB, 1)
	Write-Host "DONE: signed release AAB ($size MB) -> $output" -ForegroundColor Green
} else {
	Write-Host "WARNING: the AAB is not signed with the release key." -ForegroundColor Yellow
	Write-Host $cert
	exit 1
}
