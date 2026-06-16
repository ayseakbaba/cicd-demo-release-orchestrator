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

Write-Host "Aktif slot durduruluyor..."
Stop-WebSite -Name "$ActiveSite-API" -ErrorAction SilentlyContinue
Stop-WebSite -Name $ActiveSite       -ErrorAction SilentlyContinue

function Swap-FolderContents {
    param(
        [string]$PathA,
        [string]$PathB
    )

    $tempPath = "$PathA`_swaptmp"

    Write-Host "Swap: $PathA <-> $PathB"

    # A'yi gecici yere tasI
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    Get-ChildItem $PathA | Move-Item -Destination $tempPath -Force

    # B'yi A'ya tasI
    Get-ChildItem $PathB | Move-Item -Destination $PathA -Force

    # Geciciyi B'ye tasI
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
Start-WebSite -Name "$ActiveSite-API"
Start-WebSite -Name $ActiveSite

Write-Host "Slot swap basariyla tamamlandi."
