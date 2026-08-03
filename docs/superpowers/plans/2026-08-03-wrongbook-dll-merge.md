# Wrongbook Toolchain and DLL Merge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate overlapping toolchain entries, expand W005 with the supplied DLL/plugin ABI material and video link, and add stable navigation to the wrongbook.

**Architecture:** Keep W002 as the canonical toolchain entry and W005 as the canonical dynamic-library/ABI entry. Preserve historical numbering without reusing W003/W004, and use explicit HTML anchors so GitHub navigation remains stable if titles change.

**Tech Stack:** UTF-8 Markdown, GitHub Markdown anchors, PowerShell validation, Git.

## Global Constraints

- Merge only W002, W003, and W004 into W002; do not renumber later entries.
- Keep W005 and absorb all supplied dynamic-library/plugin-interface material into it.
- Record `https://www.bilibili.com/video/BV1vB4y1V7gR/` directly in W005.
- Keep ISO C++11 boundaries explicit; label platform/toolchain guidance separately.
- Do not copy chat text, local paths, or personal information into the wrongbook.

---

### Task 1: Consolidate canonical wrongbook entries

**Files:**
- Modify: `wrongbook/wrongbook.md`

**Interfaces:**
- Consumes: existing W002-W005 and supplied DLL/plugin notes
- Produces: canonical W002 and expanded W005

- [ ] Replace W002 with a single entry covering program/source/artifact distinctions and every toolchain error stage.
- [ ] Remove W003 and W004 without renumbering or reusing their identifiers.
- [ ] Expand W005 to cover DLL loading, ABI compatibility, stable plugin interface design, lifecycle, ownership, error handling, versioning, security, and testing.
- [ ] Add the supplied Bilibili link to W005 as an extended-learning source.

### Task 2: Add stable navigation

**Files:**
- Modify: `wrongbook/wrongbook.md`

**Interfaces:**
- Consumes: final set of W identifiers
- Produces: stable `#toc` and `#wNNN` navigation targets

- [ ] Add a table of contents after the document title.
- [ ] Add explicit `<a id="wNNN"></a>` anchors before every retained entry.
- [ ] Add a `[返回目录](#toc)` link at the end of every retained entry.
- [ ] Exclude removed W003 and W004 from the table of contents.

### Task 3: Verify and commit

**Files:**
- Test: `wrongbook/wrongbook.md`
- Test: targeted PowerShell checks and `git diff --check`

**Interfaces:**
- Consumes: updated wrongbook
- Produces: verified local Git commit

- [ ] Confirm W002 and W005 occur exactly once, while W003 and W004 do not occur as entry headings.
- [ ] Confirm every table-of-contents target has exactly one explicit anchor and every retained entry links back to `#toc`.
- [ ] Run targeted checks for the required W002/W005 content, C++11 boundaries, navigation, and forbidden personal or raw-chat content.
- [ ] Record that `tools/validate_learning_bank.ps1` is unparseable on the baseline because of corrupted text encoding; do not modify it.
- [ ] Inspect `git diff --check` and the final diff.
- [ ] Remove the temporary transformation script and commit only the wrongbook and plan.
