# Cleanup old APKs and deploy new ones
$desktopDir = "$env:USERPROFILE\OneDrive\Desktop"
$sourceDir = "$desktopDir\RoadSOS\RoadSOS"

Write-Host "Cleaning up old unversioned APKs on Desktop..."
Remove-Item -Path "$desktopDir\RoadSOS_Citizen_v2.apk" -ErrorAction SilentlyContinue
Remove-Item -Path "$desktopDir\RoadSOS_Officer_v2.apk" -ErrorAction SilentlyContinue

Write-Host "Copying new v2.1 APKs to Desktop..."
Copy-Item "$sourceDir\flutter_app_v2\build\app\outputs\flutter-apk\app-release.apk" -Destination "$desktopDir\RoadSOS_Citizen_v2.1.apk" -Force
Copy-Item "$sourceDir\officer_mobile_app\build\app\outputs\flutter-apk\app-release.apk" -Destination "$desktopDir\RoadSOS_Officer_v2.1.apk" -Force

# Generate ZIP File
$tempDir = "$desktopDir\RoadSOS_Temp_Zip"
$zipPath = "$desktopDir\RoadSOS_Complete_Project.zip"

if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

$excludeDirs = @(".git", "build", ".dart_tool", ".gradle", "node_modules", "venv", "__pycache__", "uploads", "E-commerce-Complete-Flutter-UI-master")
$excludeFiles = @("E-commerce-Complete-Flutter-UI-master.zip", "RoadSOS_Complete_Project.zip")

Write-Host "Copying files to temporary directory for packaging..."
robocopy $sourceDir $tempDir /E /XD $excludeDirs /XF $excludeFiles /R:0 /W:0 | Out-Null

Write-Host "Compressing archive to Desktop..."
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force

Write-Host "Cleaning up temporary directory..."
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue

Write-Host "Success! Clean zip created at $zipPath"
