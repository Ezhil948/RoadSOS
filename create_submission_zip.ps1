# Prepare the Hackathon Submission ZIP - STRICT SIZE OPTIMIZED
$desktopDir = "$env:USERPROFILE\OneDrive\Desktop"
$sourceDir = "$desktopDir\RoadSOS\RoadSOS"
$tempDir = "$desktopDir\RoadSOS_Final_Temp_Dir"
$zipPath = "$desktopDir\RoadSOS_Final_Submission.zip"

if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}
New-Item -ItemType Directory -Path $tempDir | Out-Null
New-Item -ItemType Directory -Path "$tempDir\Documentation" | Out-Null

# EXCLUDING UNNECESSARY HEAVY FOLDERS & OLD APPS
$excludeDirs = @(".git", "build", ".dart_tool", ".gradle", "node_modules", "venv", "__pycache__", "uploads", "kisanths_model", "apk", "flutter_app", "E-commerce-Complete-Flutter-UI-master", "images", "ios", "macos", "linux", "windows", "admin_dashboard")
$excludeFiles = @("*.zip", "*.apk", "*.exe")

Write-Host "Copying source code to temporary directory..."
robocopy $sourceDir $tempDir /E /XD $excludeDirs /XF $excludeFiles /R:0 /W:0 | Out-Null

Write-Host "Adding Detailed Document..."
if (Test-Path "$desktopDir\RoadSOS_Detailed_Document.docx") {
    Copy-Item "$desktopDir\RoadSOS_Detailed_Document.docx" -Destination "$tempDir\Documentation\RoadSOS_Detailed_Document.docx" -Force
}

# Add a README for the APKs
$readmePath = "$tempDir\README_FOR_JUDGES.txt"
"IMPORTANT NOTE FOR JUDGES:`n`nBecause of the 50MB upload limit on Unstop, the compiled .APK files could not be included directly in this ZIP archive (they are 50MB on their own).`n`nTo test the applications, please download them directly from our secure Google Drive:`n`n1. Citizen App: https://drive.google.com/file/d/1iQNCjhi1kBgCDChV4j6ttnWirOEEnK2R/view?usp=sharing`n2. Police App: https://drive.google.com/file/d/1COa7RGfdGWR0MKIyW6z3frU-FpiyykjW/view?usp=sharing`n`nAlternatively, you can run the source code provided in this archive using the Flutter CLI." | Out-File -FilePath $readmePath -Encoding utf8

Write-Host "Compressing archive to Desktop..."
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force

Write-Host "Cleaning up temporary directory..."
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue

Write-Host "Success! Clean zip created at $zipPath"
