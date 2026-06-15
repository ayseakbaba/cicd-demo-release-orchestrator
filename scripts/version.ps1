# version.ps1
# Kullanim: .\version.ps1 -ReleaseType "normal" -VersionType "minor"
# ReleaseType: normal | hotfix
# VersionType: minor | major | patch (hotfix icin otomatik patch gelir)

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("normal", "hotfix")]
    [string]$ReleaseType,

    [Parameter(Mandatory=$false)]
    [ValidateSet("minor", "major")]
    [string]$VersionType = "minor"
)

# GitHub API uzerinden mevcut tagleri cek
$headers = @{
    Authorization = "Bearer $env:RELEASE_PAT"
    Accept        = "application/vnd.github+json"
}

$owner = $env:GITHUB_REPOSITORY_OWNER
$repo  = $env:GITHUB_REPOSITORY -replace ".*/", ""

Write-Host "Tag listesi aliniyor..."

$tagsUrl  = "https://api.github.com/repos/$owner/$repo/git/refs/tags"
$response = Invoke-RestMethod -Uri $tagsUrl -Headers $headers -Method GET

# Sadece release/* formatindaki tagleri filtrele
$releaseTags = $response `
    | Where-Object { $_.ref -match "^refs/tags/release/v(\d+)\.(\d+)(?:\.(\d+))?$" } `
    | ForEach-Object {
        $null = $_.ref -match "^refs/tags/release/v(\d+)\.(\d+)(?:\.(\d+))?$"
        [PSCustomObject]@{
            Raw   = $_.ref
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = if ($Matches[3]) { [int]$Matches[3] } else { 0 }
        }
    } `
    | Sort-Object Major, Minor, Patch

if ($releaseTags.Count -eq 0) {
    # Hic tag yok, ilk release
    Write-Host "Hic release tag bulunamadi. Ilk release olusturuluyor."
    $newTag = "release/v1.0"
    Write-Host "Yeni tag: $newTag"
    echo "NEW_TAG=$newTag" >> $env:GITHUB_OUTPUT
    exit 0
}

# Son gecerli tagi al
$latest = $releaseTags | Select-Object -Last 1
Write-Host "Son gecerli tag: release/v$($latest.Major).$($latest.Minor)$(if($latest.Patch -gt 0){".$($latest.Patch)"})"

# Yeni versiyonu hesapla
if ($ReleaseType -eq "hotfix") {
    # Hotfix: patch artar
    $newMajor = $latest.Major
    $newMinor = $latest.Minor
    $newPatch  = $latest.Patch + 1
    $newTag    = "release/v$newMajor.$newMinor.$newPatch"
}
elseif ($VersionType -eq "major") {
    # Major: major artar, minor ve patch sifirlanir
    $newMajor = $latest.Major + 1
    $newMinor = 0
    $newTag   = "release/v$newMajor.$newMinor"
}
else {
    # Minor (varsayilan): minor artar, patch sifirlanir
    $newMajor = $latest.Major
    $newMinor = $latest.Minor + 1
    $newTag   = "release/v$newMajor.$newMinor"
}

Write-Host "Yeni tag: $newTag"

# GitHub Actions output olarak yaz
echo "NEW_TAG=$newTag" >> $env:GITHUB_OUTPUT
