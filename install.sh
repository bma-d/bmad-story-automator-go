#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./install.sh <bmad-project-root>

Installs the portable payload bundle into:
  _bmad/bmm/workflows/4-implementation/story-automator-go
  _bmad/bmm/workflows/4-implementation/story-automator-review

Also ensures Claude command wrappers exist in:
  .claude/commands
EOF
}

err() {
  echo "Error: $*" >&2
  exit 1
}

warn() {
  echo "Warn: $*" >&2
}

resolve_abs_dir() {
  local input="$1"
  [ -d "$input" ] || err "Directory not found: $input"
  cd "$input" >/dev/null 2>&1 && pwd
}

detect_platform() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Darwin) os="darwin" ;;
    Linux) os="linux" ;;
    *) err "Unsupported OS: $os (supported: Darwin, Linux)" ;;
  esac

  if [ "$os" = "darwin" ] && [ "$arch" = "x86_64" ]; then
    if command -v sysctl >/dev/null 2>&1; then
      if [ "$(sysctl -in hw.optional.arm64 2>/dev/null || printf '0')" = "1" ]; then
        arch="arm64"
      fi
    fi
  fi

  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    arm64|arm64e|aarch64) arch="arm64" ;;
    *) err "Unsupported architecture: $arch (supported: amd64, arm64)" ;;
  esac

  echo "${os}-${arch}"
}

backup_if_exists() {
  local path="$1"
  if [ -e "$path" ]; then
    local backup="${path}.backup-$(date -u +%Y%m%dT%H%M%SZ)"
    mv "$path" "$backup"
    echo "Backup: $backup"
  fi
}

write_claude_command() {
  local file="$1"
  local name="$2"
  local description="$3"
  local workflow_path="$4"

  if [ "$COMMAND_MODE" = "workflow-xml" ]; then
    cat >"$file" <<EOF
---
name: '${name}'
description: '${description}'
---

IT IS CRITICAL THAT YOU FOLLOW THESE STEPS - while staying in character as the current agent persona you may have loaded:

<steps CRITICAL="TRUE">
1. Always LOAD the FULL @{project-root}/_bmad/core/tasks/workflow.xml
2. READ its entire contents - this is the CORE OS for EXECUTING the specific workflow-config @{project-root}/${workflow_path}
3. Pass the workflow path @{project-root}/${workflow_path} as 'workflow-config' parameter to the workflow.xml instructions
4. Follow workflow.xml instructions EXACTLY as written to process and follow the specific workflow config and its instructions
5. Save outputs after EACH section when generating any documents from templates
</steps>
EOF
    return
  fi

  cat >"$file" <<EOF
---
name: '${name}'
description: '${description}'
---

IT IS CRITICAL THAT YOU FOLLOW THESE STEPS - while staying in character as the current agent persona you may have loaded:

<steps CRITICAL="TRUE">
1. Always LOAD the FULL @{project-root}/${workflow_path}
2. READ its entire contents - this is the COMPLETE workflow you must execute
3. Follow the workflow EXACTLY as written
4. Save outputs after EACH section when generating any documents from templates
</steps>
EOF
}

resolve_workflow_path() {
  local candidate
  for candidate in "$@"; do
    if [ -f "$TARGET_ROOT/$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

ensure_command_current() {
  local file="$1"
  local name="$2"
  local description="$3"
  local workflow_path="$4"
  local tmp action

  tmp="$(mktemp "${TMPDIR:-/tmp}/story-automator-command.XXXXXX")"
  write_claude_command "$tmp" "$name" "$description" "$workflow_path"

  if [ ! -f "$file" ]; then
    mv "$tmp" "$file"
    chmod 0644 "$file"
    echo "Created command: ${file#$TARGET_ROOT/}"
    return 0
  fi

  if cmp -s "$tmp" "$file"; then
    rm -f "$tmp"
    return 0
  fi

  mv "$tmp" "$file"
  chmod 0644 "$file"
  echo "Updated command: ${file#$TARGET_ROOT/}"
}

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

TARGET_ROOT="$(resolve_abs_dir "$1")"
TARGET_BMAD="$TARGET_ROOT/_bmad"
TARGET_WORKFLOW="$TARGET_ROOT/_bmad/bmm/workflows/4-implementation/story-automator-go"
TARGET_STORY_REVIEW="$TARGET_ROOT/_bmad/bmm/workflows/4-implementation/story-automator-review"
TARGET_COMMANDS="$TARGET_ROOT/.claude/commands"
PLATFORM="$(detect_platform)"
PAYLOAD_ROOT="$SCRIPT_DIR/payload"
STORY_PAYLOAD="$PAYLOAD_ROOT/_bmad/bmm/workflows/4-implementation/story-automator-go"
STORY_REVIEW_PAYLOAD="$PAYLOAD_ROOT/_bmad/bmm/workflows/4-implementation/story-automator-review"
SOURCE_BINARY="$SCRIPT_DIR/artifacts/story-automator/bin/$PLATFORM/story-automator"

[ -d "$TARGET_BMAD" ] || err "Target is not a BMAD project: missing $TARGET_BMAD"
[ -d "$TARGET_ROOT/_bmad/bmm/workflows/4-implementation" ] || err "Missing implementation workflows directory"
[ -d "$STORY_PAYLOAD" ] || err "Missing story-automator-go payload: $STORY_PAYLOAD"
[ -d "$STORY_REVIEW_PAYLOAD" ] || err "Missing story-automator-review payload: $STORY_REVIEW_PAYLOAD"
[ -f "$SOURCE_BINARY" ] || err "Missing packaged binary for $PLATFORM: $SOURCE_BINARY"

COMMAND_MODE="direct"
if [ -f "$TARGET_ROOT/_bmad/core/tasks/workflow.xml" ]; then
  COMMAND_MODE="workflow-xml"
fi

CREATE_STORY_PATH="$(resolve_workflow_path \
  "_bmad/bmm/workflows/4-implementation/create-story/workflow.yaml" \
  "_bmad/bmm/workflows/4-implementation/create-story/workflow.md")" \
  || err "Required workflow missing: create-story"
DEV_STORY_PATH="$(resolve_workflow_path \
  "_bmad/bmm/workflows/4-implementation/dev-story/workflow.yaml" \
  "_bmad/bmm/workflows/4-implementation/dev-story/workflow.md")" \
  || err "Required workflow missing: dev-story"
RETROSPECTIVE_PATH="$(resolve_workflow_path \
  "_bmad/bmm/workflows/4-implementation/retrospective/workflow.yaml" \
  "_bmad/bmm/workflows/4-implementation/retrospective/workflow.md")" \
  || err "Required workflow missing: retrospective"

OPTIONAL_AUTOMATE_PATH=""
if OPTIONAL_AUTOMATE_PATH="$(resolve_workflow_path \
  "_bmad/tea/workflows/testarch/automate/workflow.yaml" \
  "_bmad/tea/workflows/testarch/automate/workflow.md" \
  "_bmad/bmm/workflows/testarch/automate/workflow.yaml" \
  "_bmad/bmm/workflows/testarch/automate/workflow.md")"; then
  :
else
  warn "Optional automate workflow not found. Story-automator-go still installs, but run with 'Skip Automate' enabled unless you install testarch automate."
fi

backup_if_exists "$TARGET_WORKFLOW"
backup_if_exists "$TARGET_STORY_REVIEW"

cp -a "$STORY_PAYLOAD" "$TARGET_ROOT/_bmad/bmm/workflows/4-implementation/"
cp -a "$STORY_REVIEW_PAYLOAD" "$TARGET_ROOT/_bmad/bmm/workflows/4-implementation/"
cp -a "$SCRIPT_DIR/README.md" "$TARGET_WORKFLOW/README.md"

mkdir -p "$TARGET_WORKFLOW/bin"
cp -a "$SOURCE_BINARY" "$TARGET_WORKFLOW/bin/story-automator"
chmod +x "$TARGET_WORKFLOW/bin/story-automator"
find "$TARGET_WORKFLOW/scripts" -type f -name '*.sh' -exec chmod +x {} +

mkdir -p "$TARGET_COMMANDS"
write_claude_command \
  "$TARGET_COMMANDS/bmad-bmm-story-automator-go.md" \
  "story-automator-go" \
  "Automate the build cycle for stories in an epic using T-Mux sessions with full resumability, smart parallelism, decision escalation, and automated retrospectives (tri-modal: create, validate, edit)" \
  "_bmad/bmm/workflows/4-implementation/story-automator-go/workflow.md"

ensure_command_current \
  "$TARGET_COMMANDS/bmad-bmm-create-story.md" \
  "create-story" \
  "Create the next user story from epics+stories with enhanced context analysis and direct ready-for-dev marking" \
  "$CREATE_STORY_PATH"

ensure_command_current \
  "$TARGET_COMMANDS/bmad-bmm-dev-story.md" \
  "dev-story" \
  "Execute a story by implementing tasks/subtasks, writing tests, validating, and updating the story file per acceptance criteria" \
  "$DEV_STORY_PATH"

ensure_command_current \
  "$TARGET_COMMANDS/bmad-bmm-story-automator-review.md" \
  "story-automator-review" \
  "Run the dedicated non-interactive review workflow used by story-automator-go sessions." \
  "_bmad/bmm/workflows/4-implementation/story-automator-review/workflow.yaml"

ensure_command_current \
  "$TARGET_COMMANDS/bmad-bmm-retrospective.md" \
  "retrospective" \
  "Run after epic completion to review overall success and capture lessons learned." \
  "$RETROSPECTIVE_PATH"

if [ -n "$OPTIONAL_AUTOMATE_PATH" ]; then
  ensure_command_current \
    "$TARGET_COMMANDS/bmad-tea-testarch-automate.md" \
    "testarch-automate" \
    "Expand test automation coverage after implementation or analyze existing codebase to generate comprehensive test suite" \
    "$OPTIONAL_AUTOMATE_PATH"
fi

echo "Installed story-automator-go into: $TARGET_WORKFLOW"
echo "Installed bundled story-automator-review into: $TARGET_STORY_REVIEW"
echo "Installed binary: $PLATFORM"
echo "Command mode: $COMMAND_MODE"
echo "Installed Claude command: $TARGET_COMMANDS/bmad-bmm-story-automator-go.md"
