# version.ps1
# Kullanim:
# .\version.ps1 -ReleaseType "normal" -VersionType "minor"

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("normal", "hotfix")]
    [string]$ReleaseType,

    [Parameter(Mandatory = $false)]
    [ValidateSet("minor", "major")]
    [string]$VersionType = "minor"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:RELEASE_PAT)) {
    throw "RELEASE_PAT environment variable tanimli degil."
}

if ([string]::IsNullOrWhiteSpace($env:BACKEND_REPO)) {
    throw "BACKEND_REPO repository variable tanimli degil."
}

if ([string]::IsNullOrWhiteSpace($env:FRONTEND_REPO)) {
    throw "FRONTEND_REPO repository variable tanimli degil."
}

$headers = @{
    Authorization = "Bearer $env:RELEASE_PAT"
    Accept        = "application/vnd.github+json"
}

function Get-RepositoryTags {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository
    )

    $allTags = @()
    $page = 1

    do {
        $tagsUrl = "https://api.github.com/repos/${Repository}/tags?per_page=100&page=$page"
        Write-Host "--------------------------------"
        Write-Host "GitHub API istegi atiliyor"
        Write-Host "Owner: $owner"
        Write-Host "Repo: $repo"
        Write-Host "Tags URL: $tagsUrl"
        Write-Host "--------------------------------"
        Write-Host "Tag listesi aliniyor: $Repository - Sayfa: $page"

        try {
            $currentPageTags = @(
                Invoke-RestMethod `
                    -Uri $tagsUrl `
                    -Headers $headers `
                    -Method GET `
                    -ErrorAction Stop
            )
        }
        catch {
            throw "Tag listesi alinamadi. Repository: $Repository. Hata: $($_.Exception.Message)"
        }

        $allTags += $currentPageTags
        $page++

    } while ($currentPageTags.Count -eq 100)

    return $allTags
}

Write-Host "Backend repository : $env:BACKEND_REPO"
Write-Host "Frontend repository: $env:FRONTEND_REPO"

# Backend ve frontend taglerini birlikte oku.
# Böylece frontend-only veya backend-only hotfix tagleri de hesaba katilir.
$allTags = @()

$allTags += Get-RepositoryTags -Repository $env:BACKEND_REPO
$allTags += Get-RepositoryTags -Repository $env:FRONTEND_REPO

$tagPattern = "^release/v(?<major>\d+)\.(?<minor>\d+)(?:\.(?<patch>\d+))?$"

$releaseTags = @(
    $allTags |
        ForEach-Object {
            $match = [regex]::Match($_.name, $tagPattern)

            if ($match.Success) {
                [PSCustomObject]@{
                    Raw   = $_.name
                    Major = [int]$match.Groups["major"].Value
                    Minor = [int]$match.Groups["minor"].Value
                    Patch = if ($match.Groups["patch"].Success) {
                        [int]$match.Groups["patch"].Value
                    }
                    else {
                        0
                    }
                }
            }
        } |
        Sort-Object Major, Minor, Patch
)

if ($releaseTags.Count -eq 0) {
    Write-Host "Hic release tag bulunamadi. Ilk release olusturuluyor."

    $newTag = "release/v1.0"

    Write-Host "Yeni tag: $newTag"

    "NEW_TAG=$newTag" |
        Out-File `
            -FilePath $env:GITHUB_OUTPUT `
            -Encoding utf8 `
            -Append

    exit 0
}

$latest = $releaseTags | Select-Object -Last 1

Write-Host "Son gecerli tag: $($latest.Raw)"

if ($ReleaseType -eq "hotfix") {
    $newMajor = $latest.Major
    $newMinor = $latest.Minor
    $newPatch = $latest.Patch + 1

    $newTag = "release/v$newMajor.$newMinor.$newPatch"
}
elseif ($VersionType -eq "major") {
    $newMajor = $latest.Major + 1
    $newMinor = 0

    $newTag = "release/v$newMajor.$newMinor"
}
else {
    $newMajor = $latest.Major
    $newMinor = $latest.Minor + 1

    $newTag = "release/v$newMajor.$newMinor"
}

Write-Host "Yeni tag: $newTag"

"NEW_TAG=$newTag" |
    Out-File `
        -FilePath $env:GITHUB_OUTPUT `
        -Encoding utf8 `
        -Append
