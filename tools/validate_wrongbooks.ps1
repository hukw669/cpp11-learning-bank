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

function Get-MarkdownStructureText {
    param(
        [string]$BookName,
        [string]$Text
    )

    $builder = [System.Text.StringBuilder]::new($Text.Length)
    $insideFence = $false
    $fenceCharacter = ''
    $fenceLength = 0

    foreach ($lineMatch in [regex]::Matches($Text, '[^\r\n]*(?:\r\n|\n|\r|$)')) {
        if ($lineMatch.Length -eq 0) {
            continue
        }

        $lineWithEnding = $lineMatch.Value
        $newline = if ($lineWithEnding.EndsWith("`r`n")) {
            "`r`n"
        }
        elseif ($lineWithEnding.EndsWith("`n")) {
            "`n"
        }
        elseif ($lineWithEnding.EndsWith("`r")) {
            "`r"
        }
        else {
            ''
        }
        $line = $lineWithEnding.Substring(0, $lineWithEnding.Length - $newline.Length)
        $openingFence = [regex]::Match('', '$^')

        if (-not $insideFence) {
            $openingFence = [regex]::Match($line, '^[ ]{0,3}(`{3,}|~{3,})')
            if ($openingFence.Success) {
                $insideFence = $true
                $fenceSequence = $openingFence.Groups[1].Value
                $fenceCharacter = $fenceSequence.Substring(0, 1)
                $fenceLength = $fenceSequence.Length
            }
        }
        else {
            $closingPattern = '^[ ]{0,3}' + [regex]::Escape($fenceCharacter) + '{' + $fenceLength + ',}[ \t]*$'
            if ($line -match $closingPattern) {
                $insideFence = $false
            }
        }

        if ($insideFence -or $openingFence.Success) {
            [void]$builder.Append(' ' * $line.Length)
            [void]$builder.Append($newline)
        }
        else {
            [void]$builder.Append($lineWithEnding)
        }
    }

    if ($insideFence) {
        $errors.Add("$BookName 错题本存在未闭合的 Markdown $fenceCharacter 围栏")
    }

    $builder.ToString()
}

function Add-MalformedIdErrors {
    param(
        [string]$BookName,
        [string]$Text,
        [string]$IdPattern,
        [string]$AnchorPattern
    )

    $tocHeading = [regex]::Match($Text, '(?m)^## [^\r\n]*错题目录[^\r\n]*$')
    if (-not $tocHeading.Success) {
        $errors.Add("$BookName 错题本缺少错题目录标题")
        return
    }

    $tocAnchors = @([regex]::Matches($Text, '(?m)^<a id="toc"></a>\s*$'))
    if ($tocAnchors.Count -ne 1) {
        $errors.Add("$BookName 错题本的 toc 锚点数量为 $($tocAnchors.Count)，应为 1")
    }
    elseif ($tocAnchors[0].Index -gt $tocHeading.Index) {
        $errors.Add("$BookName 错题本的 toc 锚点必须位于错题目录标题之前")
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

    $entryText = $Text.Substring($tocStart)
    foreach ($match in [regex]::Matches($entryText, '(?m)^<a id="([A-Za-z]+[0-9]+)"></a>\s*$')) {
        $anchorId = $match.Groups[1].Value
        if ($anchorId -notmatch "^$AnchorPattern$") {
            $errors.Add("$BookName 错题本的锚点包含格式错误的 ID：$anchorId")
        }
    }

    foreach ($match in [regex]::Matches($entryText, '(?m)^## ([A-Za-z]+[0-9]+)：.+$')) {
        $headingId = $match.Groups[1].Value
        if ($headingId -notmatch "^$IdPattern$") {
            $errors.Add("$BookName 错题本的正文包含格式错误的 ID：$headingId")
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
    $structureText = Get-MarkdownStructureText -BookName $book.Name -Text $text
    $idPattern = "$($book.Prefix)[0-9]{3}"
    $anchorPattern = "$($book.AnchorPrefix)[0-9]{3}"

    Add-MalformedIdErrors -BookName $book.Name -Text $structureText -IdPattern $idPattern -AnchorPattern $anchorPattern
    $navigationIds = @(Get-Ids -Text $structureText -Pattern "(?m)^- \[($idPattern)：[^\]]+\]\(#$anchorPattern\)\s*$")
    $anchorIds = @(Get-Ids -Text $structureText -Pattern "(?m)^<a id=`"($anchorPattern)`"></a>\s*$" |
        ForEach-Object { $_.ToUpperInvariant() })
    $headingIds = @(Get-Ids -Text $structureText -Pattern "(?m)^## ($idPattern)：.+$")
    $headingMatches = @([regex]::Matches($structureText, "(?m)^## ($idPattern)：.+$"))
    $returnMatches = @([regex]::Matches($structureText, '(?m)^\[返回目录\]\(#toc\)\s*$'))

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
        $entryEnd = if ($index + 1 -lt $headingMatches.Count) { $headingMatches[$index + 1].Index } else { $structureText.Length }
        $entryReturnLinks = @($returnMatches | Where-Object { $_.Index -gt $entryStart -and $_.Index -lt $entryEnd })
        $assignedReturnLinks += $entryReturnLinks.Count
        if ($entryReturnLinks.Count -ne 1) {
            $errors.Add("$($book.Name) 错题本的 $($headingIds[$index]) 条目返回目录链接数为 $($entryReturnLinks.Count)，应为 1")
        }
    }

    if ($returnMatches.Count -ne $assignedReturnLinks) {
        $errors.Add("$($book.Name) 错题本存在 $($returnMatches.Count - $assignedReturnLinks) 个不在正文条目内的返回目录链接")
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
