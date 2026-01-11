#!/usr/bin/env bash
# Git utilities for branch management

# Check if working directory has uncommitted changes
is_working_directory_dirty() {
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    return 0  # Dirty
  else
    return 1  # Clean
  fi
}

# Check if a git branch exists
branch_exists() {
  local branch_name="$1"

  if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
    return 0  # Exists
  else
    return 1  # Does not exist
  fi
}

# Get current branch name
get_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Create and checkout a new git branch for a loop
# Returns 0 on success, 1 on failure
create_loop_branch() {
  local loop_name="$1"
  local branch_name="ralph/$loop_name"

  # Check if working directory is dirty
  if is_working_directory_dirty; then
    warning "Working directory has uncommitted changes"
    echo ""
    echo "You have uncommitted changes in your working directory."
    echo "It's recommended to commit or stash them before creating a new branch."
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Branch creation cancelled"
      return 1
    fi
    echo ""
  fi

  # Check if branch already exists
  if branch_exists "$branch_name"; then
    local current_branch
    current_branch=$(get_current_branch)

    if [[ "$current_branch" == "$branch_name" ]]; then
      info "Already on branch: $branch_name"
      return 0
    else
      warning "Branch already exists: $branch_name"
      echo ""
      echo "A branch with this name already exists."
      read -p "Check out the existing branch? (y/N) " -n 1 -r
      echo ""
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        if git checkout "$branch_name" 2>/dev/null; then
          success "Checked out existing branch: $branch_name"
          return 0
        else
          error "Failed to checkout branch: $branch_name"
          return 1
        fi
      else
        echo "Continuing without branch checkout"
        return 1
      fi
    fi
  fi

  # Create and checkout new branch
  info "Creating and checking out branch: $branch_name"
  if git checkout -b "$branch_name" 2>/dev/null; then
    success "Created and checked out branch: $branch_name"
    return 0
  else
    error "Failed to create branch: $branch_name"
    return 1
  fi
}
