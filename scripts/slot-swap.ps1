# slot-swap.ps1
# IIS sitelerini durdurur, klasor iceriklerini swap eder, yeniden baslatir
param(
    [Parameter(Mandatory=$true)] [string]$ActiveSite,
    [Parameter(Mandatory=$true)] [string]$StagingSite,
    [Parameter(Mandatory=$true)] [string]$ActiveBackendPath,
    [Parameter(Mandatory=$true)] [string]$StagingBackendPath,
    [Parameter(Mandatory=$true)] [string]$ActiveFrontendPath,
    [Parameter(Mandatory=$true)] [string]$StagingFrontendPath
)

Import-Module WebAdministration

# Aktif slot pool isimlerini siteden dinamik cek
$activeApiSite = "$ActiveSite-API"
$activePool    = (Get-Website -Name $ActiveSite).applicationPool
$activeApiPool = (Get-Website -Name $activeApiSite).applicationPool

Write-Host "Aktif slot durduruluyor..."
Stop-WebSite -Name $activeApiSite -ErrorAction SilentlyContinue
Stop-WebSite -Name $ActiveSite    -ErrorAction SilentlyContinue

# Uygulama havuzlarini durdur
Stop-WebAppPool -Name $activePool    -ErrorAction SilentlyContinue
Stop-WebAppPool -Name $activeApiPool -ErrorAction SilentlyContinue

# Havuzlarin durmasini bekle
Start-Sleep -Seconds 3

function Swap-FolderContents {
    param(
        [string]$PathA,
        [string]$PathB
    )
    $tempPath = "$PathA`_swaptmp"
    Write-Host "Swap: $PathA <-> $PathB"
    # A'yi gecici yere tasi
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    Get-ChildItem $PathA | Move-Item -Destination $tempPath -Force
    # B'yi A'ya tasi
    Get-ChildItem $PathB | Move-Item -Destination $PathA -Force
    # Geciciyi B'ye tasi
    Get-ChildItem $tempPath | Move-Item -Destination $PathB -Force
    # Gecici klasoru sil
    Remove-Item $tempPath -Recurse -Force
    Write-Host "Swap tamamlandi."
}

# Backend swap
Swap-FolderContents -PathA $ActiveBackendPath -PathB $StagingBackendPath
# Frontend swap
Swap-FolderContents -PathA $ActiveFrontendPath -PathB $StagingFrontendPath

Write-Host "Aktif slot baslatiliyor..."
# Uygulama havuzlarini baslat
Start-WebAppPool -Name $activeApiPool
Start-WebAppPool -Name $activePool

Start-WebSite -Name $activeApiSite
Start-WebSite -Name $ActiveSite

Write-Host "Slot swap basariyla tamamlandi."
