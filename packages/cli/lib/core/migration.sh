#!/usr/bin/env bash
# migration.sh - Auto-migration from Ralph v1 to v2 (BMAD-native)
# Called automatically on first command after ralph update

# Get LIB_DIR from main script or fallback to relative path
readonly MIGRATION_LIB_DIR="${LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)}"

# Source bmad_config utilities
# shellcheck source=lib/core/bmad_config.sh
source "$MIGRATION_LIB_DIR/core/bmad_config.sh"

# Current Ralph version
RALPH_VERSION="2.0"

# Check if migration is needed and perform it
# Returns 0 if no migration needed or migration succeeded
# Returns 1 if migration failed
check_and_migrate() {
  # Skip if not a BMAD project
  if [[ ! -f "bmad/config.yaml" ]]; then
    return 0
  fi

  # Check for v1 installation marker: ralph/config.yaml exists
  if [[ -f "ralph/config.yaml" ]]; then
    # Check if already migrated (ralph section exists in bmad/config.yaml)
    if yq eval '.ralph // ""' bmad/config.yaml 2>/dev/null | grep -q "version"; then
      # Already has ralph section, just need to clean up old file
      cleanup_v1_files
      return 0
    fi

    # Perform migration
    migrate_v1_to_v2
    return $?
  fi

  return 0
}

# Migrate from v1 (ralph/config.yaml) to v2 (bmad/config.yaml ralph section)
migrate_v1_to_v2() {
  echo ""
  info "Migrating Ralph to v2 (BMAD-native)..."
  echo ""

  local old_config="ralph/config.yaml"

  # 1. Read existing ralph/config.yaml values
  local max_iter stuck_thresh
  max_iter=$(yq eval '.defaults.max_iterations // 50' "$old_config" 2>/dev/null)
  stuck_thresh=$(yq eval '.defaults.stuck_threshold // 3' "$old_config" 2>/dev/null)

  # Read quality gates
  local qg_typecheck qg_test qg_lint qg_build
  qg_typecheck=$(yq eval '.defaults.quality_gates.typecheck // null' "$old_config" 2>/dev/null)
  qg_test=$(yq eval '.defaults.quality_gates.test // null' "$old_config" 2>/dev/null)
  qg_lint=$(yq eval '.defaults.quality_gates.lint // null' "$old_config" 2>/dev/null)
  qg_build=$(yq eval '.defaults.quality_gates.build // null' "$old_config" 2>/dev/null)

  # 2. Add ralph section to bmad/config.yaml
  info "Adding ralph section to bmad/config.yaml..."

  local temp_file
  temp_file=$(mktemp)

  # Build the ralph section using yq
  yq eval "
    .ralph.version = \"$RALPH_VERSION\" |
    .ralph.migrated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\" |
    .ralph.defaults.max_iterations = $max_iter |
    .ralph.defaults.stuck_threshold = $stuck_thresh |
    .ralph.defaults.quality_gates.typecheck = $qg_typecheck |
    .ralph.defaults.quality_gates.test = $qg_test |
    .ralph.defaults.quality_gates.lint = $qg_lint |
    .ralph.defaults.quality_gates.build = $qg_build |
    .ralph.loops_dir = \"ralph/loops\" |
    .ralph.archive_dir = \"ralph/archive\"
  " bmad/config.yaml > "$temp_file"

  if [[ $? -eq 0 ]] && yq eval '.' "$temp_file" >/dev/null 2>&1; then
    mv "$temp_file" bmad/config.yaml
    success "Updated bmad/config.yaml with ralph section"
  else
    rm -f "$temp_file"
    error "Failed to update bmad/config.yaml"
    return 1
  fi

  # 3. Migrate each loop's config.json to .state.json
  migrate_loop_configs

  # 4. Add loops to sprint-status.yaml
  migrate_loops_to_sprint_status

  # 5. Backup and remove old ralph/config.yaml
  cleanup_v1_files

  echo ""
  success "Migration to Ralph v2 complete!"
  echo ""
  echo "Changes made:"
  echo "  • Ralph configuration moved to bmad/config.yaml (ralph: section)"
  echo "  • Loop state files migrated to .state.json"
  echo "  • Active loops tracked in docs/sprint-status.yaml"
  echo "  • Old files backed up with .v1.bak extension"
  echo ""

  return 0
}

# Migrate loop config.json files to minimal .state.json
migrate_loop_configs() {
  if [[ ! -d "ralph/loops" ]]; then
    return 0
  fi

  for loop_dir in ralph/loops/*/; do
    if [[ ! -d "$loop_dir" ]]; then
      continue
    fi

    local config_file="${loop_dir}config.json"
    local state_file="${loop_dir}.state.json"

    if [[ -f "$config_file" ]]; then
      info "Migrating loop: $(basename "$loop_dir")"

      # Extract only runtime state (storyAttempts, storyNotes, stats)
      local temp_file
      temp_file=$(mktemp)

      jq '{
        storyAttempts: .storyAttempts,
        storyNotes: .storyNotes,
        stats: .stats
      }' "$config_file" > "$temp_file" 2>/dev/null

      if [[ $? -eq 0 ]] && jq '.' "$temp_file" >/dev/null 2>&1; then
        mv "$temp_file" "$state_file"

        # Backup old config.json
        mv "$config_file" "${config_file}.v1.bak"
        success "  Migrated to .state.json"
      else
        rm -f "$temp_file"
        warning "  Failed to migrate config.json, keeping original"
      fi
    fi
  done
}

# Add active loops to sprint-status.yaml
migrate_loops_to_sprint_status() {
  local sprint_file
  sprint_file=$(get_bmad_sprint_status_path)

  if [[ ! -f "$sprint_file" ]]; then
    return 0
  fi

  # Check if ralph_loops section already exists
  if yq eval '.ralph_loops // ""' "$sprint_file" 2>/dev/null | grep -q "name"; then
    return 0
  fi

  local loops_to_add=()

  # Gather loop info from each loop directory
  for loop_dir in ralph/loops/*/; do
    if [[ ! -d "$loop_dir" ]]; then
      continue
    fi

    local loop_name
    loop_name=$(basename "$loop_dir")

    # Read from either .state.json (new) or config.json.v1.bak (just migrated) or config.json
    local state_file="${loop_dir}.state.json"
    local old_config="${loop_dir}config.json.v1.bak"
    local current_config="${loop_dir}config.json"

    local branch_name="ralph/$loop_name"
    local created_at
    local status="active"
    local iterations_run=0
    local stories_completed=0

    if [[ -f "$state_file" ]]; then
      iterations_run=$(jq -r '.stats.iterationsRun // 0' "$state_file" 2>/dev/null || echo "0")
      stories_completed=$(jq -r '.stats.storiesCompleted // 0' "$state_file" 2>/dev/null || echo "0")
    fi

    if [[ -f "$old_config" ]]; then
      branch_name=$(jq -r '.branchName // "ralph/'"$loop_name"'"' "$old_config" 2>/dev/null || echo "ralph/$loop_name")
      created_at=$(jq -r '.generatedAt // ""' "$old_config" 2>/dev/null || echo "")
    elif [[ -f "$current_config" ]]; then
      branch_name=$(jq -r '.branchName // "ralph/'"$loop_name"'"' "$current_config" 2>/dev/null || echo "ralph/$loop_name")
      created_at=$(jq -r '.generatedAt // ""' "$current_config" 2>/dev/null || echo "")
    fi

    # Default created_at if not found
    if [[ -z "$created_at" ]]; then
      created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    loops_to_add+=("$loop_name|$branch_name|$created_at|$status|$iterations_run|$stories_completed")
  done

  if [[ ${#loops_to_add[@]} -eq 0 ]]; then
    return 0
  fi

  info "Adding loops to sprint-status.yaml..."

  local temp_file
  temp_file=$(mktemp)

  # Start with empty ralph_loops array
  yq eval '.ralph_loops = []' "$sprint_file" > "$temp_file"

  # Add each loop
  local idx=0
  for loop_data in "${loops_to_add[@]}"; do
    IFS='|' read -r name branch created status iter_run stories_done <<< "$loop_data"

    yq eval "
      .ralph_loops[$idx].name = \"$name\" |
      .ralph_loops[$idx].branch = \"$branch\" |
      .ralph_loops[$idx].created_at = \"$created\" |
      .ralph_loops[$idx].status = \"$status\" |
      .ralph_loops[$idx].stats.iterations_run = $iter_run |
      .ralph_loops[$idx].stats.stories_completed = $stories_done
    " "$temp_file" > "${temp_file}.2" && mv "${temp_file}.2" "$temp_file"

    ((idx++))
  done

  if yq eval '.' "$temp_file" >/dev/null 2>&1; then
    mv "$temp_file" "$sprint_file"
    success "Added ${#loops_to_add[@]} loop(s) to sprint-status.yaml"
  else
    rm -f "$temp_file"
    warning "Failed to update sprint-status.yaml with loops"
  fi
}

# Cleanup v1 files (backup and remove)
cleanup_v1_files() {
  if [[ -f "ralph/config.yaml" ]]; then
    mv "ralph/config.yaml" "ralph/config.yaml.v1.bak"
    info "Backed up ralph/config.yaml to ralph/config.yaml.v1.bak"
  fi
}

# Check if Ralph needs initialization (v2 style)
needs_ralph_init() {
  # v2: Check for ralph section in bmad/config.yaml
  if [[ -f "bmad/config.yaml" ]]; then
    if yq eval '.ralph.version // ""' bmad/config.yaml 2>/dev/null | grep -q "2"; then
      return 1  # Already initialized v2
    fi
  fi

  # v1: Check for ralph/config.yaml (will be migrated)
  if [[ -f "ralph/config.yaml" ]]; then
    return 1  # Has v1, will be migrated
  fi

  return 0  # Needs initialization
}

# Get Ralph version from bmad/config.yaml
get_ralph_version() {
  if [[ -f "bmad/config.yaml" ]]; then
    yq eval '.ralph.version // ""' bmad/config.yaml 2>/dev/null
  elif [[ -f "ralph/config.yaml" ]]; then
    echo "1.0"
  else
    echo ""
  fi
}
