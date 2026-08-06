# C++11 STL Detail Guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one deep C++11 reference page that organizes the current conversation's STL and language details around comparisons between easily confused operations.

**Architecture:** Create a single focused section document with stable `D1–D12` headings and comparison tables, then expose it through README and the total index. Treat the page as a review/deepening layer mapped to existing nodes, so the existing 533-node/690-question coverage baseline remains unchanged.

**Tech Stack:** UTF-8 Markdown, ISO C++11 examples, PowerShell validation, GCC/Clang C++11 syntax checks where available, Git.

## Global Constraints

- The C++ main line is ISO C++11.
- C++14/17/20 APIs may appear only as explicitly labeled version comparisons.
- Do not modify `questions/batch_*.md`, wrongbooks, or `tools/validate_learning_bank.ps1` coverage semantics.
- Do not copy raw chat text; reorganize it into original standalone explanations.
- Every easily confused API group must state behavior, mutation, failure mode, return value, complexity, iterator impact, example, and selection rule where applicable.
- The new page does not add claimed coverage beyond the existing 533/690 C++ baseline.

---

### Task 1: Create the C++11 STL Detail Guide

**Files:**

- Create: `sections/08_C++11细节知识点与STL易混操作.md`

**Interfaces:**

- Produces stable headings `D1` through `D12` for navigation from README and the total index.
- Consumes existing concepts `B6/B11/B13/R4/T6/S1–S12/ITER1/ALG1–ALG8` without changing their coverage accounting.

- [ ] **Step 1: Confirm the file does not already exist**

```powershell
if (Test-Path '.\sections\08_C++11细节知识点与STL易混操作.md') {
    throw 'Detail guide already exists'
}
```

Expected: exit `0`.

- [ ] **Step 2: Create the exact section skeleton**

Use these top-level section headings:

```markdown
# C++11 细节知识点与 STL 易混操作
## D1 阅读地图与版本边界
## D2 花括号初始化、临时对象与 `return {}`
## D3 `array`、`pair`、`tuple` 与 `struct`
## D4 `map` 元素、迭代器与 `first/second`
## D5 STL 初始化与增删改查总表
## D6 相似容器接口的行为差异
## D7 迭代器模型、类别与循环模板
## D8 插入删除、扩容与迭代器失效
## D9 常用算法与迭代器工具详解
## D10 位运算、逻辑运算与文字替代符
## D11 `std::move`、转发引用与 `std::forward`
## D12 选择流程、记忆口诀与检查清单
```

- [ ] **Step 3: Fill D2–D4 with type and initialization comparisons**

Include compilable C++11 examples for:

```cpp
std::array<int, 3> a{{1, 2, 3}};
std::pair<int, std::string> p{1, "Tom"};
std::tuple<int, std::string, double> t{1, "Tom", 95.5};
std::map<int, std::string> mp{{1, "Tom"}};
```

Explain outer/inner braces, contextual `initializer_list`, `pair<const Key,T>`, `it->member == (*it).member`, immutable map keys, and the absence of `third` in `pair`.

- [ ] **Step 4: Fill D5–D6 with CRUD tables and comparison cards**

Cover sequence, ordered associative, unordered associative, string, array, and adapter containers. Include these exact comparison groups:

```text
operator[] / at / find / count
insert / emplace / operator[]
push_back / emplace_back
erase / remove / remove_if
unique / global deduplication
member find / std::find
member lower_bound / std::lower_bound
array / pair / tuple / struct
```

Mark `contains`, `try_emplace`, `insert_or_assign`, and structured bindings as non-C++11.

- [ ] **Step 5: Fill D7–D9 with iterator and algorithm details**

Document iterator expressions, categories, `begin/end/cbegin/cend/rbegin/rend`, safe erase loops, and the following algorithms/tools:

```text
find count sort copy remove unique reverse
lower_bound upper_bound distance advance next prev iter_swap
```

Explicitly state sorted-range requirements, random-access requirements, erase-remove behavior, adjacent-only `unique`, output-space requirements for `copy`, and category-dependent complexity.

- [ ] **Step 6: Fill D10–D11 with operators and forwarding**

Include bitwise operators `& | ^ ~ << >>`, logical operators `&& || !`, short-circuit behavior, unsigned shift masks such as `1u << k`, and alternative tokens `bitand/bitor/xor/compl/and/or/not`.

For forwarding include the reference-collapsing table and this C++11 example:

```cpp
template<class T>
void wrapper(T&& value) {
    consume(std::forward<T>(value));
}
```

Distinguish unconditional `std::move` from conditional `std::forward` and state that named rvalue-reference variables are lvalue expressions.

- [ ] **Step 7: Add D12 decision rules and run content assertions**

```powershell
$doc = Get-Content '.\sections\08_C++11细节知识点与STL易混操作.md' -Raw
if (([regex]::Matches($doc, '(?m)^## D\d+\b')).Count -ne 12) { throw 'D node count mismatch' }
foreach ($term in @('mp[key]', 'mp.at(key)', 'std::forward', 'rehash', 'std::unique', 'std::distance')) {
    if (-not $doc.Contains($term)) { throw "Missing required term: $term" }
}
```

Expected: 12 headings and all required comparison markers present.

- [ ] **Step 8: Validate Markdown and C++11 examples**

Run:

```powershell
pwsh -NoProfile -File .\tools\validate_learning_bank.ps1 -RequireFullCoverage
pwsh -NoProfile -File .\tools\validate_wrongbooks.ps1
git diff --check -- sections/08_C++11细节知识点与STL易混操作.md
```

Expected: 533 nodes, 690 questions, 0 missing; wrongbooks valid; no whitespace errors.

- [ ] **Step 9: Commit the guide**

```powershell
git add -- sections/08_C++11细节知识点与STL易混操作.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: add C++11 STL detail guide"
```

Expected staged path: exactly the new section file.

---

### Task 2: Add Navigation and Perform Final Verification

**Files:**

- Modify: `README.md`
- Modify: `00_总图与选题索引.md`

**Interfaces:**

- Consumes: `sections/08_C++11细节知识点与STL易混操作.md` and its `D1–D12` headings.
- Produces: stable repository navigation without changing coverage totals.

- [ ] **Step 1: Add README entry points**

Add the new file to the repository tree and learning order. Describe it as a C++11 detail/review guide and state that it maps to existing nodes rather than increasing the 533-node count.

- [ ] **Step 2: Add the total-index detail table**

Add a `### G. C++11 STL 细节专题` section containing one row for each `D1–D12` heading and an existing-node mapping column. Link the heading to `sections/08_C++11细节知识点与STL易混操作.md`.

- [ ] **Step 3: Verify navigation and unchanged scope**

```powershell
$readme = Get-Content '.\README.md' -Raw
$index = Get-Content '.\00_总图与选题索引.md' -Raw
$path = 'sections/08_C++11细节知识点与STL易混操作.md'
if (-not (Test-Path $path)) { throw 'Missing detail guide' }
if (-not $readme.Contains('08_C++11细节知识点与STL易混操作.md')) { throw 'README link missing' }
if (-not $index.Contains('D1–D12')) { throw 'Index range missing' }
if (-not $readme.Contains('533/533') -or -not $readme.Contains('690')) { throw 'C++ baseline missing' }
```

- [ ] **Step 4: Run final validators**

```powershell
pwsh -NoProfile -File .\tools\validate_learning_bank.ps1 -RequireFullCoverage
pwsh -NoProfile -File .\tools\validate_wrongbooks.ps1
git diff --check
```

Expected: 533/690/0 baseline, valid wrongbooks, clean diff.

- [ ] **Step 5: Commit navigation**

```powershell
git add -- README.md 00_总图与选题索引.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: index C++11 STL detail guide"
```

Expected staged paths: exactly README and the total index.

- [ ] **Step 6: Verify final branch state**

```powershell
git status --short --branch
git log -3 --oneline
git diff --check HEAD~2..HEAD
```

Expected: clean worktree and the two intentional product commits after the design/plan commits.
