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

foreach ($book in $books) {
    $path = Join-Path $repositoryRoot $book.Path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("缺少错题本文件：$($book.Path)")
        continue
    }

    $text = Get-Content -LiteralPath $path -Raw
    $idPattern = "$($book.Prefix)[0-9]{3}"
    $anchorPattern = "$($book.AnchorPrefix)[0-9]{3}"

    $navigationIds = @(Get-Ids -Text $text -Pattern "(?m)^- \[($idPattern)：[^\]]+\]\(#$anchorPattern\)\s*$")
    $anchorIds = @(Get-Ids -Text $text -Pattern "(?m)^<a id=`"($anchorPattern)`"></a>\s*$" |
        ForEach-Object { $_.ToUpperInvariant() })
    $headingIds = @(Get-Ids -Text $text -Pattern "(?m)^## ($idPattern)：.+$")
    $returnLinks = [regex]::Matches($text, '(?m)^\[返回目录\]\(#toc\)\s*$').Count
    $fenceCount = [regex]::Matches($text, '(?m)^```').Count

    Add-DuplicateError -BookName $book.Name -Source '目录' -Ids $navigationIds
    Add-DuplicateError -BookName $book.Name -Source '锚点' -Ids $anchorIds
    Add-DuplicateError -BookName $book.Name -Source '正文' -Ids $headingIds

    if (($navigationIds -join ',') -ne ($anchorIds -join ',')) {
        $errors.Add("$($book.Name) 错题本的目录与锚点顺序或 ID 不一致")
    }

    if (($navigationIds -join ',') -ne ($headingIds -join ',')) {
        $errors.Add("$($book.Name) 错题本的目录与正文顺序或 ID 不一致")
    }

    if ($returnLinks -ne $headingIds.Count) {
        $errors.Add("$($book.Name) 错题本的返回目录链接数为 $returnLinks，应为 $($headingIds.Count)")
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
