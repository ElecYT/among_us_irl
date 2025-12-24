$ErrorActionPreference = "Stop"
$REPO_NAME = "among_us_irl"

flutter pub get
flutter build web --release --base-href "/$REPO_NAME/"

if (Test-Path docs) { Remove-Item -Recurse -Force docs }
New-Item -ItemType Directory docs | Out-Null
Copy-Item -Recurse build\web\* docs\

git add docs
git commit -m "Deploy web" 2>$null
git push