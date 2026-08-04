# OS and Network Wrongbooks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing C++ interview-preparation repository with dedicated operating-system and computer-network knowledge maps and wrongbooks while preserving the current 690-question C++ baseline.

**Architecture:** Keep one Git repository and route technical questions into three independent Markdown wrongbooks. Preserve `wrongbook/wrongbook.md` for C++, add `OSW` and `NETW` books, migrate the current network-only W043 into NETW001, and validate every book with a dedicated PowerShell structural validator. New OS and network knowledge maps are indexed but deliberately excluded from the existing 533-node/690-question coverage metric until questions are generated.

**Tech Stack:** UTF-8 Markdown, PowerShell 7 validation scripts, Git, GitHub Markdown anchors, RFC Editor source links.

## Global Constraints

- Keep the repository and remote name `cpp11-learning-bank` unchanged.
- Preserve all existing 690 questions and the current 533/533 C++ knowledge-node baseline.
- Preserve current C++ wrongbook path `wrongbook/wrongbook.md` and all historical IDs except moving current W043 content.
- Use `WNNN` for C++, `OSWNNN` for operating systems, and `NETWNNN` for computer networks.
- Never reuse deleted IDs; each book advances from its own historical maximum.
- Store one full copy of a cross-topic question in the primary wrongbook and use links for secondary associations.
- Distinguish ISO C++ rules, textbook abstractions, POSIX/Linux behavior, protocol versions, and common implementations.
- Do not copy the supplied Zhihu article; retain only an original summary, corrections, and its source URL.
- Only one agent may write a given wrongbook at a time, and agents must serialize Git index operations.
- Push only by safe fast-forward; never force-push.

---

## File Map

**Create:**

- `sections/06_操作系统八股.md` — operating-system knowledge map.
- `sections/07_计算机网络八股.md` — computer-network knowledge map.
- `wrongbook/os_wrongbook.md` — OS question history using `OSWNNN`.
- `wrongbook/network_wrongbook.md` — network question history using `NETWNNN`.
- `tools/validate_wrongbooks.ps1` — validates navigation and numbering in all three wrongbooks.

**Modify:**

- `wrongbook/wrongbook.md` — remove current W043 after migration.
- `README.md` — describe the C++ interview-library scope and expose OS/network entry points.
- `00_总图与选题索引.md` — index OS and network nodes without altering current coverage totals.
- `SOURCES.md` — add OS/network primary-source sections.
- `AGENTS.md` — route questions and writers to the correct wrongbook.
- `docs/错题本维护规则.md` — document three prefixes, routing, migration, and cross-topic deduplication.
- `docs/题库生成与维护规则.md` — preserve current baseline while defining future subject-aware generation.

**Must not modify:**

- `questions/batch_*.md`
- Existing C++ knowledge content in `sections/01_*.md` through `sections/05_*.md`
- `tools/validate_learning_bank.ps1` coverage semantics

---

### Task 1: Add the Three-Wrongbook Structural Validator and Empty Subject Books

**Files:**

- Create: `tools/validate_wrongbooks.ps1`
- Create: `wrongbook/os_wrongbook.md`
- Create: `wrongbook/network_wrongbook.md`

**Interfaces:**

- Produces: `pwsh -NoProfile -File .\tools\validate_wrongbooks.ps1`
- Output contract: one summary row per wrongbook followed by `错题本结构校验通过。`
- Exit contract: `0` when all structures match; `1` when a file is missing, an ID is malformed/duplicated, navigation differs from headings, or fences are unbalanced.

- [ ] **Step 1: Write the validator before creating the two subject files**

Create a PowerShell script with these exact configurations:

```powershell
$books = @(
    @{ Name = 'C++'; Path = 'wrongbook/wrongbook.md'; Prefix = 'W'; AnchorPrefix = 'w' },
    @{ Name = 'OS'; Path = 'wrongbook/os_wrongbook.md'; Prefix = 'OSW'; AnchorPrefix = 'osw' },
    @{ Name = 'NET'; Path = 'wrongbook/network_wrongbook.md'; Prefix = 'NETW'; AnchorPrefix = 'netw' }
)
```

For each book, derive IDs independently from:

```text
目录：    - [ID：标题](#lowercase-id)
锚点：    <a id="lowercase-id"></a>
正文：    ## ID：标题
返回：    [返回目录](#toc)
```

The validator must compare ordered ID lists, reject duplicates, require an even number of Markdown fences, and accept zero-entry OS/NET books.

- [ ] **Step 2: Run the validator and verify the missing-file failure**

Run:

```powershell
pwsh -NoProfile -File .\tools\validate_wrongbooks.ps1
```

Expected: exit `1`, naming both missing files rather than silently skipping them.

- [ ] **Step 3: Create empty OS and network wrongbook skeletons**

Use this structure for each file, with the subject-specific title:

```markdown
# 操作系统错题本与主动提问

<a id="toc"></a>
## 错题目录

暂无条目。首次技术提问使用 `OSW001`。
```

The network book uses `# 计算机网络错题本与主动提问` and `NETW001`.

- [ ] **Step 4: Run validator and baseline question checks**

Run:

```powershell
pwsh -NoProfile -File .\tools\validate_wrongbooks.ps1
pwsh -NoProfile -File .\tools\validate_learning_bank.ps1 -RequireFullCoverage
git diff --check
```

Expected:

- C++ wrongbook: 39 entries before migration.
- OS wrongbook: 0 entries.
- NET wrongbook: 0 entries.
- Learning bank: 533 nodes, 690 questions, 0 missing.
- All commands exit `0` except the intentional failure already observed in Step 2.

- [ ] **Step 5: Commit**

```powershell
git add -- tools/validate_wrongbooks.ps1 wrongbook/os_wrongbook.md wrongbook/network_wrongbook.md
git diff --cached --check
git diff --cached --name-only
git commit -m "tools: validate subject wrongbooks"
```

Expected staged files: exactly the three files owned by this task.

---

### Task 2: Migrate C++ W043 into Network NETW001

**Files:**

- Modify: `wrongbook/wrongbook.md`
- Modify: `wrongbook/network_wrongbook.md`

**Interfaces:**

- Consumes: the three-book validator from Task 1.
- Produces: one canonical network entry with anchor `netw001` and heading `NETW001`.

- [ ] **Step 1: Record the pre-migration assertions**

Run:

```powershell
$cpp = Get-Content .\wrongbook\wrongbook.md -Raw
$net = Get-Content .\wrongbook\network_wrongbook.md -Raw
if ($cpp -notmatch '(?m)^## W043：') { throw 'Expected W043 before migration' }
if ($net -match '(?m)^## NETW001：') { throw 'NETW001 must not exist before migration' }
```

Expected: exit `0`.

- [ ] **Step 2: Move the entry without copying it**

In `wrongbook/wrongbook.md` remove exactly:

- the W043 directory item;
- `<a id="w043"></a>`;
- the W043 heading and full body;
- W043's final `[返回目录](#toc)`.

In `wrongbook/network_wrongbook.md` replace the empty message with:

```markdown
- [NETW001：怎样串联应用层、传输层和 IP 层？](#netw001)
```

Then add the migrated body using:

```markdown
<a id="netw001"></a>
## NETW001：怎样串联应用层、传输层和 IP 层？
```

Preserve the original explanation, article URL, RFC links, and closing return link. Replace only W043-specific identity text with NETW001 identity text.

- [ ] **Step 3: Verify migration uniqueness and structure**

Run:

```powershell
$cpp = Get-Content .\wrongbook\wrongbook.md -Raw
$net = Get-Content .\wrongbook\network_wrongbook.md -Raw
if ($cpp -match '(?m)^(?:## W043：|<a id="w043"></a>|- \[W043：)') { throw 'W043 remains in C++ wrongbook' }
if (([regex]::Matches($net, '(?m)^## NETW001：')).Count -ne 1) { throw 'NETW001 heading count mismatch' }
if (-not $net.Contains('https://zhuanlan.zhihu.com/p/685903962')) { throw 'Article source missing' }
pwsh -NoProfile -File .\tools\validate_wrongbooks.ps1
pwsh -NoProfile -File .\tools\validate_learning_bank.ps1 -RequireFullCoverage
git diff --check
```

Expected:

- C++ wrongbook: 38 entries.
- OS wrongbook: 0 entries.
- NET wrongbook: 1 entry.
- Existing learning bank remains 533/690/0.

- [ ] **Step 4: Commit**

```powershell
git add -- wrongbook/wrongbook.md wrongbook/network_wrongbook.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: move network notes to dedicated wrongbook"
```

---

### Task 3: Create OS and Network Knowledge Maps and Source Registry

**Files:**

- Create: `sections/06_操作系统八股.md`
- Create: `sections/07_计算机网络八股.md`
- Modify: `SOURCES.md`

**Interfaces:**

- Produces OS node prefixes: `OS1` through `OS10`.
- Produces network node prefixes: `NET1` through `NET10`.
- Provides stable source links consumed by future wrongbook and question writers.

- [ ] **Step 1: Write content-presence checks and observe failure**

Run before creating the files:

```powershell
if (Test-Path .\sections\06_操作系统八股.md) { throw 'OS file unexpectedly exists' }
if (Test-Path .\sections\07_计算机网络八股.md) { throw 'NET file unexpectedly exists' }
```

Expected: exit `0`, confirming the test starts from a missing-feature state.

- [ ] **Step 2: Create the OS knowledge map**

Write `sections/06_操作系统八股.md` with exactly these top-level node headings:

```markdown
# 操作系统八股知识图谱
## OS1 内核态、用户态、中断、异常与系统调用
## OS2 进程、线程、状态与上下文切换
## OS3 CPU 调度
## OS4 并发、临界区与同步原语
## OS5 死锁
## OS6 地址空间与虚拟内存
## OS7 文件与文件系统
## OS8 I/O、设备、DMA 与缓存
## OS9 进程间通信
## OS10 Linux 面试连接点
```

Each node must contain: definition, core mechanism, one interview distinction, common boundary/error, and prerequisite/related node. Mark Linux/POSIX-specific behavior explicitly.

- [ ] **Step 3: Create the network knowledge map**

Write `sections/07_计算机网络八股.md` with exactly these top-level node headings:

```markdown
# 计算机网络八股知识图谱
## NET1 网络分层、封装与寻址
## NET2 应用层协议
## NET3 UDP、TCP、QUIC 与端口
## NET4 TCP 可靠性、控制与连接管理
## NET5 IP、CIDR、子网与转发
## NET6 ARP/NDP、ICMP、MTU 与分片
## NET7 路由协议与最长前缀匹配
## NET8 以太网、交换、VLAN 与链路层
## NET9 NAT、代理、防火墙与负载均衡
## NET10 Socket 与 C++ 网络编程连接点
```

NET1/2/3/5/6 must incorporate the NETW001 knowledge chain while distinguishing application messages, transport ports, end-to-end IP addresses, and per-hop MAC addresses. Explicitly correct DNS UDP-only, HTTP TCP-only, classful-addressing, RARP, and IP-reliability misconceptions.

- [ ] **Step 4: Register primary and secondary sources**

Add `## 操作系统来源` and `## 计算机网络来源` to `SOURCES.md`. Include at least:

```text
https://zhuanlan.zhihu.com/p/685903962
https://www.rfc-editor.org/rfc/rfc791.html
https://www.rfc-editor.org/rfc/rfc8200.html
https://www.rfc-editor.org/rfc/rfc7766.html
https://www.rfc-editor.org/rfc/rfc9110.html
https://www.rfc-editor.org/rfc/rfc9114.html
https://www.rfc-editor.org/rfc/rfc2131.html
```

Label the Zhihu page as a secondary overview and RFC Editor pages as primary protocol sources.

- [ ] **Step 5: Verify headings, boundaries, links, and unchanged baseline**

Run:

```powershell
$os = Get-Content .\sections\06_操作系统八股.md -Raw
$net = Get-Content .\sections\07_计算机网络八股.md -Raw
if (([regex]::Matches($os, '(?m)^## OS\d+\b')).Count -ne 10) { throw 'OS node count mismatch' }
if (([regex]::Matches($net, '(?m)^## NET\d+\b')).Count -ne 10) { throw 'NET node count mismatch' }
if (-not $net.Contains('DNS') -or -not $net.Contains('QUIC') -or -not $net.Contains('最长前缀')) { throw 'Network boundary coverage missing' }
pwsh -NoProfile -File .\tools\validate_learning_bank.ps1 -RequireFullCoverage
pwsh -NoProfile -File .\tools\validate_wrongbooks.ps1
git diff --check
```

Expected: 10 OS nodes, 10 NET nodes, existing baseline 533/690/0.

- [ ] **Step 6: Commit**

```powershell
git add -- sections/06_操作系统八股.md sections/07_计算机网络八股.md SOURCES.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: add OS and network knowledge maps"
```

---

### Task 4: Route Navigation, Agents, Wrongbook Rules, and Future Questions

**Files:**

- Modify: `README.md`
- Modify: `00_总图与选题索引.md`
- Modify: `AGENTS.md`
- Modify: `docs/错题本维护规则.md`
- Modify: `docs/题库生成与维护规则.md`

**Interfaces:**

- Consumes: paths and prefixes established in Tasks 1–3.
- Produces: repository-wide routing contract for future main agents and subagents.

- [ ] **Step 1: Add a failing routing-presence check**

Run before editing:

```powershell
$agents = Get-Content .\AGENTS.md -Raw
if ($agents.Contains('OSWNNN') -or $agents.Contains('NETWNNN')) { throw 'Routing unexpectedly already exists' }
```

Expected: exit `0`.

- [ ] **Step 2: Update README and total index**

In `README.md`:

- change the displayed title/description to “C++ 八股知识库” while explicitly preserving repository name;
- list `sections/06_操作系统八股.md` and `sections/07_计算机网络八股.md`;
- list all three wrongbooks;
- keep 533/533 and 690 as the current C++ baseline;
- state that OS/NET question coverage has not yet been generated.

In `00_总图与选题索引.md`:

- add an OS module table with OS1–OS10;
- add a network module table with NET1–NET10;
- add a learning stage after the existing C++ stages;
- keep the current coverage table values unchanged and label their scope.

- [ ] **Step 3: Update AGENTS routing and writer ownership**

Add this routing table to `AGENTS.md`:

```text
C++/STL/编译链接/动态库/C++并发 → wrongbook/wrongbook.md (WNNN)
操作系统                           → wrongbook/os_wrongbook.md (OSWNNN)
计算机网络                         → wrongbook/network_wrongbook.md (NETWNNN)
```

Require one canonical full entry for cross-topic questions, relative links for secondary topics, one writer per target file, and serialized staging/committing across all agents.

- [ ] **Step 4: Update wrongbook and question-generation rules**

In `docs/错题本维护规则.md`:

- define the three files and prefixes;
- make “historical maximum + 1” apply independently per file;
- show templates for W, OSW, and NETW anchors/headings;
- define cross-topic routing and source-quality boundaries;
- keep automatic recording and deduplication behavior.

In `docs/题库生成与维护规则.md`:

- identify the current 533/690 baseline as C++ scope;
- require future OS/NET questions to identify their subject and stable node;
- forbid counting OS/NET nodes as covered until direct questions exist;
- preserve 30-question batch and answer-adjacency rules.

- [ ] **Step 5: Validate all navigation targets and rule markers**

Run:

```powershell
$requiredFiles = @(
    'sections/06_操作系统八股.md',
    'sections/07_计算机网络八股.md',
    'wrongbook/os_wrongbook.md',
    'wrongbook/network_wrongbook.md'
)
foreach ($path in $requiredFiles) { if (-not (Test-Path $path)) { throw "Missing $path" } }

$agents = Get-Content .\AGENTS.md -Raw
foreach ($term in @('OSWNNN','NETWNNN','os_wrongbook.md','network_wrongbook.md')) {
    if (-not $agents.Contains($term)) { throw "AGENTS missing $term" }
}

pwsh -NoProfile -File .\tools\validate_learning_bank.ps1 -RequireFullCoverage
pwsh -NoProfile -File .\tools\validate_wrongbooks.ps1
git diff --check
```

Expected: all files exist, all routing markers exist, validators pass.

- [ ] **Step 6: Commit**

```powershell
git add -- README.md 00_总图与选题索引.md AGENTS.md docs/错题本维护规则.md docs/题库生成与维护规则.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: route OS and network study content"
```

---

### Task 5: Final Independent Verification and Safe Publication

**Files:**

- Verify only; modify only files already listed if a check exposes a defect.

**Interfaces:**

- Consumes all deliverables from Tasks 1–4.
- Produces a clean branch whose commits are safe to fast-forward onto `origin/main`.

- [ ] **Step 1: Run full validators from a clean index**

Run:

```powershell
git status --short
pwsh -NoProfile -File .\tools\validate_learning_bank.ps1 -RequireFullCoverage
pwsh -NoProfile -File .\tools\validate_wrongbooks.ps1
git diff --check origin/main..HEAD
```

Expected:

- no uncommitted files;
- 533 knowledge nodes, 690 questions, 0 missing;
- C++/OS/NET wrongbooks contain 38/0/1 entries;
- no whitespace errors.

- [ ] **Step 2: Verify migration, maps, rules, and commit scope**

Run:

```powershell
$cpp = Get-Content .\wrongbook\wrongbook.md -Raw
$netBook = Get-Content .\wrongbook\network_wrongbook.md -Raw
$osMap = Get-Content .\sections\06_操作系统八股.md -Raw
$netMap = Get-Content .\sections\07_计算机网络八股.md -Raw

if ($cpp -match '(?m)^(?:## W043：|<a id="w043"></a>|- \[W043：)') { throw 'W043 migration incomplete' }
if (([regex]::Matches($netBook, '(?m)^## NETW001：')).Count -ne 1) { throw 'NETW001 missing or duplicated' }
if (([regex]::Matches($osMap, '(?m)^## OS\d+\b')).Count -ne 10) { throw 'OS map incomplete' }
if (([regex]::Matches($netMap, '(?m)^## NET\d+\b')).Count -ne 10) { throw 'NET map incomplete' }

git log --oneline origin/main..HEAD
git diff --name-only origin/main..HEAD
```

Expected changed paths are limited to the design/plan documents and the create/modify lists in this plan. No `questions/batch_*.md` file may appear.

- [ ] **Step 3: Perform a read-only reviewer pass**

Review for:

- OS textbook abstraction versus Linux/POSIX implementation labels;
- current versus historical network protocol behavior;
- duplicate full content across wrongbooks;
- broken relative links;
- false claims that OS/NET nodes already have question coverage.

Any correction must be followed by rerunning Steps 1 and 2 and committing only the corrected owned files.

- [ ] **Step 4: Fetch and prove fast-forward safety**

Run:

```powershell
git fetch origin main
git merge-base --is-ancestor origin/main HEAD
git rev-list --left-right --count origin/main...HEAD
```

Expected: ancestor command exits `0`; left count is `0`. If not, stop without pushing and report both hashes.

- [ ] **Step 5: Push and verify remote hash**

Run only after Step 4 passes:

```powershell
git push -u origin codex/os-network-wrongbooks
git push origin HEAD:main
git fetch origin main
if ((git rev-parse HEAD) -ne (git rev-parse origin/main)) { throw 'Remote main mismatch' }
git status --short --branch
```

Expected: feature branch and `main` contain the same final commit, no force push, clean worktree.
