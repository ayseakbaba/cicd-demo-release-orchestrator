# download-artifacts.ps1
# Backend ve frontend artifactlarini indirir

param(
    [Parameter(Mandatory=$true)]
    [string]$Tag,
    
    [Parameter(Mandatory=$true)]
    [string]$BackendRepo,
    
    [Parameter(Mandatory=$true)]
    [string]$FrontendRepo,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

$headers = @{
    Authorization = "Bearer $env:RELEASE_PAT"
    Accept        = "application/vnd.github+json"
}

$safeTag = $Tag -replace "/", "-"

function Download-Artifact {
    param(
        [string]$Repo,
        [string]$ArtifactName,
        [string]$DestPath
    )

    Write-Host "Artifact aranıyor: $ArtifactName ($Repo)"

    # Repo'daki tum artifactlari listele
    $url       = "https://api.github.com/repos/$Repo/actions/artifacts?name=$ArtifactName&per_page=10"
    $response  = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
    
    if ($response.total_count -eq 0) {
        throw "Artifact bulunamadi: $ArtifactName ($Repo)"
    }

    # En son artifact'i al
    $artifact = $response.artifacts | Sort-Object created_at -Descending | Select-Object -First 1
    Write-Host "Artifact bulundu: $($artifact.name) (id: $($artifact.id), created: $($artifact.created_at))"

    # Artifact'i indir
    $downloadUrl  = "https://api.github.com/repos/$Repo/actions/artifacts/$($artifact.id)/zip"
    $zipPath      = "$OutputPath\$ArtifactName.zip"

    if (!(Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    Invoke-RestMethod `
        -Uri $downloadUrl `
        -Headers $headers `
        -Method GET `
        -OutFile $zipPath

    # Zip'i ac
    $extractPath = "$OutputPath\$ArtifactName"
    if (Test-Path $extractPath) {
        Remove-Item $extractPath -Recurse -Force
    }
    
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Remove-Item $zipPath -Force

    Write-Host "Artifact indirildi ve acildi: $extractPath"
    return $extractPath
}

# Backend artifact indir
$backendDest  = "$OutputPath\backend"
Download-Artifact -Repo $BackendRepo -ArtifactName "backend-$safeTag" -DestPath $backendDest

# Frontend artifact indir
$frontendDest = "$OutputPath\frontend"
Download-Artifact -Repo $FrontendRepo -ArtifactName "frontend-$safeTag" -DestPath $frontendDest

Write-Host "Tum artifactlar indirildi."
Write-Host "Backend  : $backendDest\backend-$safeTag"
Write-Host "Frontend : $frontendDest\frontend-$safeTag"

# GitHub Output'a yaz
echo "BACKEND_PATH=$backendDest\backend-$safeTag"  >> $env:GITHUB_OUTPUT
echo "FRONTEND_PATH=$frontendDest\frontend-$safeTag" >> $env:GITHUB_OUTPUT
