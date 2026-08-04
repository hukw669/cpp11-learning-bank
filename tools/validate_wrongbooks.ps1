$ErrorActionPreference = 'Stop'

$books = @(
    @{ Name = 'C++'; Path = 'wrongbook/wrongbook.md'; Prefix = 'W'; AnchorPrefix = 'w' },
    @{ Name = 'OS'; Path = 'wrongbook/os_wrongbook.md'; Prefix = 'OSW'; AnchorPrefix = 'osw' },
    @{ Name = 'NET'; Path = 'wrongbook/network_wrongbook.md'; Prefix = 'NETW'; AnchorPrefix = 'netw' }
)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()
$summaries = [System.Collections.Generic.List[object]]::new()

function Get-Ids {
    param(
        [string]$Text,
        [string]$Pattern
    )

    @([regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline) |
        ForEach-Object { $_.Groups[1].Value })
}

function Add-DuplicateError {
    param(
        [string]$BookName,
        [string]$Source,
        [string[]]$Ids
    )

    $duplicates = @($Ids | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicates.Count -gt 0) {
        $errors.Add("$BookName 错题本的 $Source 存在重复 ID：$($duplicates -join ', ')")
    }
}

function Add-MalformedIdErrors {
    param(
        [string]$BookName,
        [string]$Text,
        [string]$Prefix,
        [string]$AnchorPrefix,
        [string]$IdPattern,
        [string]$AnchorPattern
    )

    $tocHeading = [regex]::Match($Text, '(?m)^## [^\r\n]*错题目录[^\r\n]*$')
    if (-not $tocHeading.Success) {
        $errors.Add("$BookName 错题本缺少错题目录标题")
        return
    }

    $tocStart = $tocHeading.Index + $tocHeading.Length
    $firstEntryAnchor = [regex]::Match($Text.Substring($tocStart), '(?m)^<a id="[^"]+"></a>\s*$')
    $tocEnd = if ($firstEntryAnchor.Success) { $tocStart + $firstEntryAnchor.Index } else { $Text.Length }
    $tocText = $Text.Substring($tocStart, $tocEnd - $tocStart)

    foreach ($match in [regex]::Matches($tocText, '(?m)^- \[([^：\]]+)：[^\]]+\]\(#([^)]+)\)\s*$')) {
        $navigationId = $match.Groups[1].Value
        $anchorId = $match.Groups[2].Value
        if ($navigationId -notmatch "^$IdPattern$" -or $anchorId -notmatch "^$AnchorPattern$") {
            $errors.Add("$BookName 错题本的目录包含格式错误的 ID：$navigationId / #$anchorId")
        }
    }

    foreach ($match in [regex]::Matches($Text.Substring($tocEnd), '(?m)^<a id="([^"]+)"></a>\s*\r?\n\s*^## ([^：\s]+)：.+$')) {
        $anchorId = $match.Groups[1].Value
        $headingId = $match.Groups[2].Value
        if ($anchorId -notmatch "^$AnchorPattern$" -or $headingId -notmatch "^$IdPattern$" -or $anchorId -ne $headingId.ToLowerInvariant()) {
            $errors.Add("$BookName 错题本的锚点/正文包含格式错误或不一致的 ID：$anchorId / $headingId")
        }
    }
}

foreach ($book in $books) {
    $path = Join-Path $repositoryRoot $book.Path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("缺少错题本文件：$($book.Path)")
        continue
    }

    $text = Get-Content -LiteralPath $path -Raw
    $idPattern = "$($book.Prefix)[0-9]{3}"
    $anchorPattern = "$($book.AnchorPrefix)[0-9]{3}"

    Add-MalformedIdErrors -BookName $book.Name -Text $text -Prefix $book.Prefix -AnchorPrefix $book.AnchorPrefix -IdPattern $idPattern -AnchorPattern $anchorPattern
    $navigationIds = @(Get-Ids -Text $text -Pattern "(?m)^- \[($idPattern)：[^\]]+\]\(#$anchorPattern\)\s*$")
    $anchorIds = @(Get-Ids -Text $text -Pattern "(?m)^<a id=`"($anchorPattern)`"></a>\s*$" |
        ForEach-Object { $_.ToUpperInvariant() })
    $headingIds = @(Get-Ids -Text $text -Pattern "(?m)^## ($idPattern)：.+$")
    $headingMatches = @([regex]::Matches($text, "(?m)^## ($idPattern)：.+$"))
    $returnMatches = @([regex]::Matches($text, '(?m)^\[返回目录\]\(#toc\)\s*$'))
    $fenceCount = [regex]::Matches($text, '(?m)^[ ]{0,3}`{3,}').Count

    Add-DuplicateError -BookName $book.Name -Source '目录' -Ids $navigationIds
    Add-DuplicateError -BookName $book.Name -Source '锚点' -Ids $anchorIds
    Add-DuplicateError -BookName $book.Name -Source '正文' -Ids $headingIds

    if (($navigationIds -join ',') -ne ($anchorIds -join ',')) {
        $errors.Add("$($book.Name) 错题本的目录与锚点顺序或 ID 不一致")
    }

    if (($navigationIds -join ',') -ne ($headingIds -join ',')) {
        $errors.Add("$($book.Name) 错题本的目录与正文顺序或 ID 不一致")
    }

    $assignedReturnLinks = 0
    for ($index = 0; $index -lt $headingMatches.Count; $index++) {
        $entryStart = $headingMatches[$index].Index
        $entryEnd = if ($index + 1 -lt $headingMatches.Count) { $headingMatches[$index + 1].Index } else { $text.Length }
        $entryReturnLinks = @($returnMatches | Where-Object { $_.Index -gt $entryStart -and $_.Index -lt $entryEnd })
        $assignedReturnLinks += $entryReturnLinks.Count
        if ($entryReturnLinks.Count -ne 1) {
            $errors.Add("$($book.Name) 错题本的 $($headingIds[$index]) 条目返回目录链接数为 $($entryReturnLinks.Count)，应为 1")
        }
    }

    if ($returnMatches.Count -ne $assignedReturnLinks) {
        $errors.Add("$($book.Name) 错题本存在 $($returnMatches.Count - $assignedReturnLinks) 个不在正文条目内的返回目录链接")
    }

    if (($fenceCount % 2) -ne 0) {
        $errors.Add("$($book.Name) 错题本的 Markdown 代码围栏数量为奇数：$fenceCount")
    }

    $summaries.Add([pscustomobject]@{
            Name = $book.Name
            Entries = $headingIds.Count
        })
}

foreach ($summary in $summaries) {
    "$($summary.Name) 错题本：$($summary.Entries) 条"
}

if ($errors.Count -gt 0) {
    foreach ($validationError in $errors) {
        [Console]::Error.WriteLine($validationError)
    }
    exit 1
}

'错题本结构校验通过。'
