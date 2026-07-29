param(
    [switch]$RequireFullCoverage
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$questionDirectory = Join-Path $repositoryRoot 'questions'

function Get-UniqueOrdered {
    param([string[]]$Values)

    $seen = @{}
    foreach ($value in $Values) {
        if (-not $seen.ContainsKey($value)) {
            $seen[$value] = $true
            $value
        }
    }
}

function Get-KnowledgeNodes {
    $nodes = [System.Collections.Generic.List[string]]::new()

    $coreText = Get-Content (Join-Path $repositoryRoot 'sections/01_基础核心.md') -Raw
    foreach ($match in [regex]::Matches($coreText, '(?m)^###\s+(B\d+\.\d+)\b')) {
        $nodes.Add($match.Groups[1].Value)
    }

    $classLines = Get-Content (Join-Path $repositoryRoot 'sections/02_类模板STL.md')
    $insideConfusionIndex = $false
    foreach ($line in $classLines) {
        if ($line -eq '# 重点易混点索引') {
            $insideConfusionIndex = $true
            continue
        }

        if ($insideConfusionIndex -and $line -match '^# C\+\+11 边界') {
            $insideConfusionIndex = $false
        }

        if ($line -match '^###\s+((?:O|R|T|L|S)\d+\.\d+)\b') {
            $nodes.Add($matches[1])
            continue
        }

        if ($line -match '^###\s+(X\d{2})\b') {
            $nodes.Add($matches[1])
            continue
        }

        if ($line -match '^##\s+(R9)\b') {
            $nodes.Add($matches[1])
            continue
        }

        if ($insideConfusionIndex -and $line -match '^- `?(X\d{2})`?：') {
            $nodes.Add($matches[1])
        }
    }

    $systemLines = Get-Content (Join-Path $repositoryRoot 'sections/03_系统并发工程.md')
    foreach ($line in $systemLines) {
        if ($line -match '^- \[[ xX]\] `((?:EX|MEM|TH|AT|IO|BUILD|CMAKE|LINUX)-\d{2})`') {
            $nodes.Add($matches[1])
        }
    }

    @(Get-UniqueOrdered -Values $nodes)
}

function Get-QuestionNodeIds {
    param([string]$Heading)

    $pattern = '(?:B\d+\.\d+|(?:O|R|T|L|S)\d+(?:\.\d+)?|X\d{2}|(?:EX|MEM|TH|AT|IO|BUILD|CMAKE|LINUX)-\d{2})'
    @([regex]::Matches($Heading, $pattern) | ForEach-Object { $_.Value })
}

$knownNodes = @(Get-KnowledgeNodes)
$questionFiles = @(Get-ChildItem $questionDirectory -File -Filter 'batch_*.md' | Sort-Object Name)
$allQuestionNumbers = [System.Collections.Generic.List[int]]::new()
$coveredNodes = [System.Collections.Generic.List[string]]::new()
$errors = [System.Collections.Generic.List[string]]::new()

foreach ($file in $questionFiles) {
    if ($file.Name -notmatch '^batch_(\d{2})_(\d{3})_(\d{3})\.md$') {
        $errors.Add("文件名不符合规则：$($file.Name)")
        continue
    }

    $expectedStart = [int]$matches[2]
    $expectedEnd = [int]$matches[3]
    $text = Get-Content $file.FullName -Raw
    $headings = @([regex]::Matches($text, '(?m)^#{2,3}\s*(\d{3})[.．]?[^\r\n]*'))
    $numbers = @($headings | ForEach-Object { [int]$_.Groups[1].Value })
    $answers = [regex]::Matches($text, '(?m)^\*\*答案：\*\*').Count
    $fences = [regex]::Matches($text, '(?m)^```').Count

    if ($numbers.Count -ne 30) {
        $errors.Add("$($file.Name)：题目数为 $($numbers.Count)，应为 30")
    }

    if ($answers -ne 30) {
        $errors.Add("$($file.Name)：答案数为 $answers，应为 30")
    }

    if ($numbers.Count -gt 0) {
        if ($numbers[0] -ne $expectedStart -or $numbers[-1] -ne $expectedEnd) {
            $errors.Add("$($file.Name)：题号范围与文件名不一致")
        }

        $expectedNumbers = @($expectedStart..$expectedEnd)
        if (($numbers -join ',') -ne ($expectedNumbers -join ',')) {
            $errors.Add("$($file.Name)：题号不连续或存在重复")
        }
    }

    if (($fences % 2) -ne 0) {
        $errors.Add("$($file.Name)：Markdown 代码围栏数量为奇数")
    }

    foreach ($heading in $headings) {
        $number = [int]$heading.Groups[1].Value
        $allQuestionNumbers.Add($number)
        $nodeIds = @(Get-QuestionNodeIds -Heading $heading.Value)
        if ($nodeIds.Count -eq 0) {
            $errors.Add("$($file.Name) 第 $number 题：缺少知识节点标签")
        }
        foreach ($nodeId in $nodeIds) {
            $coveredNodes.Add($nodeId)
        }
    }
}

if ($allQuestionNumbers.Count -gt 0) {
    $orderedNumbers = @($allQuestionNumbers | Sort-Object)
    $expectedAllNumbers = @(1..$orderedNumbers[-1])
    if (($orderedNumbers -join ',') -ne ($expectedAllNumbers -join ',')) {
        $errors.Add('全题库题号不连续或存在重复')
    }
}

$uniqueCoveredNodes = @(Get-UniqueOrdered -Values $coveredNodes)
$missingNodes = @($knownNodes | Where-Object { $_ -notin $uniqueCoveredNodes })
$unknownNodes = @($uniqueCoveredNodes | Where-Object { $_ -notin $knownNodes })

if ($unknownNodes.Count -gt 0) {
    $errors.Add("题库包含知识图谱中不存在的节点：$($unknownNodes -join ', ')")
}

if ($RequireFullCoverage -and $missingNodes.Count -gt 0) {
    $errors.Add("仍有 $($missingNodes.Count) 个节点未覆盖：$($missingNodes -join ', ')")
}

[pscustomobject]@{
    KnowledgeNodes = $knownNodes.Count
    QuestionFiles = $questionFiles.Count
    Questions = $allQuestionNumbers.Count
    CoveredNodes = $uniqueCoveredNodes.Count
    MissingNodes = $missingNodes.Count
    LastQuestion = if ($allQuestionNumbers.Count -gt 0) {
        ($allQuestionNumbers | Measure-Object -Maximum).Maximum
    }
    else {
        0
    }
} | Format-List

if ($missingNodes.Count -gt 0) {
    "尚未覆盖：$($missingNodes -join ', ')"
}

if ($errors.Count -gt 0) {
    foreach ($validationError in $errors) {
        Write-Error $validationError
    }
    exit 1
}

'题库结构校验通过。'
