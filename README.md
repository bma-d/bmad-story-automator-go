# Story Automator Go

![Story Automator Go](./ref.png)

> Use this to wake up to this.

Portable runtime bundle for BMAD `story-automator-go`.

## Quickstart

Install into a BMAD project:

```bash
cd /path/to/bmad-story-automator-go
./install.sh /absolute/path/to/your-bmad-project
```

Example:

```bash
cd /path/to/bmad-story-automator-go
./install.sh /path/to/your-bmad-project
```

Verify the package:

```bash
cd /path/to/bmad-story-automator-go
./test-install.sh
```

## What This Is

This repo packages the runtime-only parts of `story-automator-go` so another BMAD project can install it without carrying the Go source tree or old validation artifacts.

This bundle supports:
- Claude
- Codex

This bundle does not support:
- other agent CLIs

Important:
- retrospective child runs are Claude-only even if the main orchestration uses Codex elsewhere

## What Gets Installed

The installer copies bundled payload into the target project:
- `_bmad/bmm/workflows/4-implementation/story-automator-go`
- `_bmad/bmm/workflows/4-implementation/code-review`

It also:
- installs the correct platform binary as `bin/story-automator`
- installs the Claude command `bmad-bmm-story-automator-go`
- creates missing Claude dependency commands for `create-story`, `dev-story`, `code-review`, `retrospective`
- creates `bmad-tea-testarch-automate` only if a compatible automate workflow already exists in the target project

## Why Code Review Is Bundled

`story-automator-go` now depends on the updated `code-review` workflow state gate.

Critical rule:
- a story should move to `done` only when **zero CRITICAL issues remain after fixes**

Because of that, this package installs the bundled `code-review` workflow alongside `story-automator-go`. If the target project keeps an older review workflow, the automator can incorrectly move stories to `done`.

## Requirements

Target project must already have:
- `_bmad/bmm/workflows/4-implementation/create-story/workflow.yaml` or `.md`
- `_bmad/bmm/workflows/4-implementation/dev-story/workflow.yaml` or `.md`
- `_bmad/bmm/workflows/4-implementation/retrospective/workflow.yaml` or `.md`

Optional target project file:
- `_bmad/core/tasks/workflow.xml`

Optional automate workflow:
- `_bmad/tea/workflows/testarch/automate/workflow.yaml` or `.md`
- or `_bmad/bmm/workflows/testarch/automate/workflow.yaml` or `.md`

Host requirements:
- `tmux`
- Claude CLI and/or Codex CLI
- macOS or Linux
- `amd64` or `arm64`

If the automate workflow is missing, install still succeeds. In that case run `story-automator-go` with `Skip Automate = true`.

## How To Use It

### Claude

After install:

```text
/bmad-bmm-story-automator-go
```

That command runs:
- `_bmad/core/tasks/workflow.xml` when the project uses the workflow engine
- `_bmad/bmm/workflows/4-implementation/story-automator-go/workflow.md`

### Codex

Codex does not use the Claude slash-command wrapper. Use a direct prompt like:

```text
Load _bmad/core/tasks/workflow.xml, then execute _bmad/bmm/workflows/4-implementation/story-automator-go/workflow.md exactly as written.
```

The packaged runtime supports Claude and Codex child sessions during orchestration. Codex-specific monitoring and prompt handling are included. Retrospective sessions still force Claude.

## How To Verify A Target Install

Manual checks inside a target project:

```bash
cd /path/to/project
_bmad/bmm/workflows/4-implementation/story-automator-go/scripts/derive-project-slug.sh
grep -n "0 CRITICAL issues remain after fixes" _bmad/bmm/workflows/4-implementation/code-review/instructions.xml
```

Expected:
- JSON containing `"ok": true`
- a matching `CRITICAL issues remain` line in `code-review/instructions.xml`

## Package Layout

Payload copied into target projects:
- `payload/_bmad/bmm/workflows/4-implementation/story-automator-go/`
- `payload/_bmad/bmm/workflows/4-implementation/code-review/`

Packaged binaries:
- `artifacts/story-automator/bin/darwin-arm64/story-automator`
- `artifacts/story-automator/bin/darwin-amd64/story-automator`
- `artifacts/story-automator/bin/linux-arm64/story-automator`
- `artifacts/story-automator/bin/linux-amd64/story-automator`

Package scripts:
- `install.sh`
- `test-install.sh`

## What Is Intentionally Excluded

- `cmd/`
- `go.mod`
- source-only root binaries from the source workflow folder
- `validation-history.md`
- `validation-report-*.md`
- `validation-reports/`
- planning/archive docs like `workflow-plan*.md`

## Notes For Maintainers

- this repo is a distributable runtime bundle, not the development source repo
- if you need to rebuild binaries, do that from the source workflow repo that still contains `cmd/story-automator`
- installer backs up existing target `story-automator-go` and `code-review` folders before replacing them
