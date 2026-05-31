# RoadSOS AI Setup Script
Write-Host "Setting up Python Backend..."
cd backend
pip install -r requirements.txt
cd ..

Write-Host "Setting up Citizen App (v2)..."
cd flutter_app_v2
flutter pub get
cd ..

Write-Host "Setting up Police App..."
cd officer_mobile_app
flutter pub get
cd ..

Write-Host "RoadSOS environment is fully configured!"
