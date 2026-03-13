#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_PROJECT_DEFAULT=""
if [ -d "$SCRIPT_DIR/../bmad-test-project" ]; then
  TEST_PROJECT_DEFAULT="$(cd "$SCRIPT_DIR/../bmad-test-project" && pwd)"
fi
TEST_PROJECT="${1:-$TEST_PROJECT_DEFAULT}"

WORKFLOW_DIR="$TEST_PROJECT/_bmad/bmm/workflows/4-implementation/story-automator-go"
REVIEW_DIR="$TEST_PROJECT/_bmad/bmm/workflows/4-implementation/code-review"
COMMAND_DIR="$TEST_PROJECT/.claude/commands"
BIN_REL="_bmad/bmm/workflows/4-implementation/story-automator-go/bin/story-automator"
SCRIPT_REL="_bmad/bmm/workflows/4-implementation/story-automator-go/scripts/derive-project-slug.sh"

err() {
  echo "Error: $*" >&2
  exit 1
}

cleanup_prior_install() {
  rm -rf "$WORKFLOW_DIR"
  rm -f "$COMMAND_DIR/bmad-bmm-story-automator-go.md"
  rm -f "$COMMAND_DIR/bmad-bmm-create-story.md"
  rm -f "$COMMAND_DIR/bmad-bmm-dev-story.md"
  rm -f "$COMMAND_DIR/bmad-bmm-code-review.md"
  rm -f "$COMMAND_DIR/bmad-bmm-retrospective.md"
  rm -f "$COMMAND_DIR/bmad-tea-testarch-automate.md"
}

[ -n "$TEST_PROJECT" ] || err "No test project provided. Pass a path explicitly or place bmad-test-project next to this package."
[ -d "$TEST_PROJECT" ] || err "Test project not found: $TEST_PROJECT"

cleanup_prior_install
"$SCRIPT_DIR/install.sh" "$TEST_PROJECT"

[ -f "$WORKFLOW_DIR/workflow.md" ] || err "workflow.md missing after install"
[ -d "$WORKFLOW_DIR/data" ] || err "data dir missing after install"
[ -d "$WORKFLOW_DIR/scripts" ] || err "scripts dir missing after install"
[ -d "$WORKFLOW_DIR/steps-c" ] || err "steps-c dir missing after install"
[ -d "$WORKFLOW_DIR/steps-e" ] || err "steps-e dir missing after install"
[ -d "$WORKFLOW_DIR/steps-v" ] || err "steps-v dir missing after install"
[ -d "$WORKFLOW_DIR/templates" ] || err "templates dir missing after install"
[ -x "$WORKFLOW_DIR/bin/story-automator" ] || err "binary missing or not executable after install"
[ -f "$REVIEW_DIR/workflow.yaml" ] || err "bundled code-review workflow missing after install"
[ -f "$REVIEW_DIR/instructions.xml" ] || err "bundled code-review instructions missing after install"
[ -f "$REVIEW_DIR/checklist.md" ] || err "bundled code-review checklist missing after install"
[ -f "$COMMAND_DIR/bmad-bmm-story-automator-go.md" ] || err "story-automator-go command missing after install"

slug_json="$(cd "$TEST_PROJECT" && "$SCRIPT_REL")"
echo "$slug_json" | grep -q '"ok":true' || err "derive-project-slug returned unexpected payload: $slug_json"
echo "$slug_json" | grep -q '"projectRoot":"'"$TEST_PROJECT"'"' || err "derive-project-slug projectRoot mismatch: $slug_json"
grep -q '0 CRITICAL issues remain after fixes' "$REVIEW_DIR/instructions.xml" || err "bundled code-review DONE gate text missing"

echo "Install test passed."
echo "$slug_json"
