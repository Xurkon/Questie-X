param(
    [string]$InputFile,
    [string]$OutputDir,
    [string]$TableKey,
    [int]$MaxKB = 850
)

$lines = Get-Content $InputFile
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)

$dataStartLine = ($lines | Select-String -Pattern "^\[" | Select-Object -First 1).LineNumber - 1
$totalLines = $lines.Count

Write-Host "Processing $InputFile"
Write-Host "Data entries start at line $($dataStartLine+1) of $totalLines"

$header = "-- AUTO GENERATED FILE! DO NOT EDIT! (split chunk)`r`nif not QuestieLoader then return end`r`nlocal QuestieDB = QuestieLoader:ImportModule(`"QuestieDB`")`r`nQuestieDB.$TableKey = QuestieDB.$TableKey or {}`r`nlocal _d = QuestieDB.$TableKey`r`n"

$chunkIndex = 1
$currentLines = New-Object System.Collections.Generic.List[string]
$currentLines.Add($header)
$currentSize = [System.Text.Encoding]::UTF8.GetByteCount($header)

for ($i = $dataStartLine; $i -lt $totalLines; $i++) {
    $line = $lines[$i]
    if ($line -match "^\}\]\]") { break }
    $converted = $line -replace "^\[(\d+)\]\s*=", "_d[`$1] ="
    $lineBytes = [System.Text.Encoding]::UTF8.GetByteCount($converted + "`n")

    if ($currentSize + $lineBytes -gt ($MaxKB * 1024) -and $currentLines.Count -gt 5) {
        $outFile = Join-Path $OutputDir "${baseName}_${chunkIndex}.lua"
        $currentLines | Set-Content $outFile
        Write-Host "  Wrote chunk $chunkIndex -> $outFile ($([math]::Round($currentSize/1KB))KB)"
        $chunkIndex++
        $currentLines = New-Object System.Collections.Generic.List[string]
        $currentLines.Add($header)
        $currentSize = [System.Text.Encoding]::UTF8.GetByteCount($header)
    }

    $currentLines.Add($converted)
    $currentSize += $lineBytes
}

if ($currentLines.Count -gt 5) {
    $outFile = Join-Path $OutputDir "${baseName}_${chunkIndex}.lua"
    $currentLines | Set-Content $outFile
    Write-Host "  Wrote chunk $chunkIndex -> $outFile ($([math]::Round($currentSize/1KB))KB)"
}
Write-Host "Done. $chunkIndex chunks written."
