# Sprint Plan: Ralph

**Date:** 2026-01-10
**Scrum Master:** jean-philippebrule
**Project Level:** 3 (Complex)
**Total Stories:** 26
**Total Points:** 91
**Planned Sprints:** 3

---

## Executive Summary

This sprint plan breaks down the Ralph autonomous execution workflow into 26 implementable user stories across 3 sprints. Ralph is a BMAD Phase 5 workflow that reads all project documentation, configures an autonomous loop, and executes Claude Code iterations until all stories pass quality gates.

**Key Metrics:**
- Total Stories: 26
- Total Points: 91
- Sprints: 3 (6 weeks)
- Team Capacity: 30 points per sprint
- Target Completion: Sprint 3

---

## Story Inventory

### EPIC-001: BMAD Document Ingestion

**Priority:** Must Have | **FR:** FR-001 | **Estimated Points:** 13

---

#### STORY-001: Read Product Brief Document

**Epic:** EPIC-001
**Priority:** Must Have
**Points:** 2

**User Story:**
As a developer, I want Ralph to find and read my product brief so that it understands the project vision and constraints.

**Acceptance Criteria:**
- [ ] Locates `docs/product-brief-*.md` using glob pattern
- [ ] Extracts executive summary for project overview
- [ ] Extracts problem statement and solution overview
- [ ] Extracts constraints and assumptions
- [ ] Handles missing product brief gracefully (warning, not error)
- [ ] Typecheck passes

**Technical Notes:**
- Use Glob tool to find files matching pattern
- Parse markdown sections using header detection
- Store extracted content in workflow state

**Dependencies:** None

---

#### STORY-002: Parse PRD Document

**Epic:** EPIC-001
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer, I want Ralph to parse my PRD so that it knows all functional requirements and acceptance criteria.

**Acceptance Criteria:**
- [ ] Locates `docs/prd-*.md` using glob pattern
- [ ] Extracts all functional requirements (FR-XXX sections)
- [ ] Extracts acceptance criteria for each FR
- [ ] Extracts all epics with their FR mappings
- [ ] Extracts non-functional requirements
- [ ] Reports count of FRs, NFRs, and epics found
- [ ] Typecheck passes

**Technical Notes:**
- Parse markdown headings to identify FR/NFR sections
- Build structured data from parsed sections
- PRD is required - fail if not found

**Dependencies:** None

---

#### STORY-003: Read Architecture Document

**Epic:** EPIC-001
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer, I want Ralph to read my architecture doc so that generated code follows the right patterns and tech stack.

**Acceptance Criteria:**
- [ ] Locates `docs/architecture-*.md` using glob pattern
- [ ] Extracts technology stack decisions
- [ ] Extracts architectural patterns and component structure
- [ ] Extracts data schemas and file structures
- [ ] Extracts implementation principles
- [ ] Architecture is required for Level 2+ - fail if not found
- [ ] Typecheck passes

**Technical Notes:**
- Focus on extracting actionable implementation guidance
- Include code examples and schemas in prompt context

**Dependencies:** None

---

#### STORY-004: Parse Sprint Status YAML

**Epic:** EPIC-001
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer, I want Ralph to parse sprint-status.yaml so that it knows which stories to work on and their status.

**Acceptance Criteria:**
- [ ] Locates `docs/sprint-status.yaml`
- [ ] Parses YAML structure using BMAD format
- [ ] Extracts all epics with their stories
- [ ] Extracts story status (not_started, in_progress, done)
- [ ] Extracts story dependencies
- [ ] Reports count of stories by status
- [ ] Typecheck passes

**Technical Notes:**
- Use yq or parse YAML manually in workflow
- Build story list for scope selection

**Dependencies:** None

---

#### STORY-005: Read Individual Story Files

**Epic:** EPIC-001
**Priority:** Must Have
**Points:** 2

**User Story:**
As a developer, I want Ralph to read individual story files so that it gets detailed implementation guidance.

**Acceptance Criteria:**
- [ ] Locates `docs/stories/**/*.md` using glob pattern
- [ ] Matches story files to sprint-status entries by ID
- [ ] Extracts full story description and acceptance criteria
- [ ] Extracts technical notes and dependencies
- [ ] Handles missing story files gracefully
- [ ] Typecheck passes

**Technical Notes:**
- Story files provide more detail than sprint-status.yaml
- Merge story file content with sprint-status data

**Dependencies:** STORY-004

---

### EPIC-002: Loop Configuration Interview

**Priority:** Must Have | **FR:** FR-002 | **Estimated Points:** 10

---

#### STORY-006: Display Documentation Summary

**Epic:** EPIC-002
**Priority:** Must Have
**Points:** 2

**User Story:**
As a developer, I want Ralph to show me what docs it found so that I can verify it has the right context.

**Acceptance Criteria:**
- [ ] Displays count of each document type found
- [ ] Shows project name and type from config
- [ ] Shows count of epics and stories from PRD/sprint-status
- [ ] Shows count by story status (pending, in_progress, done)
- [ ] Lists any missing optional documents
- [ ] Format is clear and scannable
- [ ] Typecheck passes

**Technical Notes:**
- Display before asking configuration questions
- Use consistent formatting (table or list)

**Dependencies:** STORY-001 through STORY-005

---

#### STORY-007: Scope Selection Interview

**Epic:** EPIC-002
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer, I want to select which stories to include so that I can run partial loops or focus on one epic.

**Acceptance Criteria:**
- [ ] Offers options: all pending, specific epic, specific stories
- [ ] Lists available epics with story counts
- [ ] Lists individual stories if story-level selection chosen
- [ ] Validates selection (at least one story)
- [ ] Filters stories by selection for downstream processing
- [ ] Typecheck passes

**Technical Notes:**
- Use AskUserQuestion tool for selection
- Support multiple selection modes

**Dependencies:** STORY-006

---

#### STORY-008: Quality Gates Configuration

**Epic:** EPIC-002
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer, I want to specify my quality gate commands so that Ralph enforces my project's standards.

**Acceptance Criteria:**
- [ ] Asks for typecheck command with default suggestion
- [ ] Asks for test command with default suggestion
- [ ] Asks for lint command (optional)
- [ ] Asks for build command (optional)
- [ ] Validates commands are non-empty strings
- [ ] Allows skipping optional gates (null/empty)
- [ ] Shows summary of configured gates
- [ ] Typecheck passes

**Technical Notes:**
- Common defaults: `npm run typecheck`, `npm test`, `npm run lint`
- Store in config for prd.json generation

**Dependencies:** STORY-007

---

#### STORY-009: Loop Parameters Configuration

**Epic:** EPIC-002
**Priority:** Must Have
**Points:** 2

**User Story:**
As a developer, I want to set loop parameters so that I control how long it runs and when it stops.

**Acceptance Criteria:**
- [ ] Asks for max iterations (default: 50)
- [ ] Asks for stuck threshold (default: 3)
- [ ] Asks about branch creation (yes/no, naming)
- [ ] Asks for optional custom instructions
- [ ] Validates numeric inputs are positive integers
- [ ] Shows final configuration summary for confirmation
- [ ] Typecheck passes

**Technical Notes:**
- Branch naming: `ralph/{epic-name}` or `ralph/{feature-name}`
- Custom instructions appended to prompt

**Dependencies:** STORY-008

---

### EPIC-003: Loop File Generation

**Priority:** Must Have | **FRs:** FR-003, FR-004, FR-005, FR-009 | **Estimated Points:** 23

---

#### STORY-010: Generate prd.json from Selected Stories

**Epic:** EPIC-003
**Priority:** Must Have
**Points:** 5

**User Story:**
As a developer, I want Ralph to generate prd.json from my stories so that the loop can track progress.

**Acceptance Criteria:**
- [ ] Creates `ralph/prd.json` with correct schema
- [ ] Includes project name and description from docs
- [ ] Includes branch name from configuration
- [ ] Includes all config (maxIterations, stuckThreshold, qualityGates)
- [ ] Includes stats object with initial values
- [ ] Converts each selected story to userStories array entry
- [ ] Each story includes: id, epicId, title, description, acceptanceCriteria, priority, passes=false, attempts=0
- [ ] Typecheck passes

**Technical Notes:**
- Follow schema from architecture doc exactly
- Atomic write: temp file + rename

**Dependencies:** STORY-009

---

#### STORY-011: Order Stories by Dependency

**Epic:** EPIC-003
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer, I want stories ordered by dependency so that schema changes come before backend, backend before UI.

**Acceptance Criteria:**
- [ ] Assigns priority based on story dependencies
- [ ] Infrastructure/schema stories get lowest priority numbers (first)
- [ ] Backend stories get middle priority numbers
- [ ] UI/frontend stories get higher priority numbers
- [ ] Integration stories get highest priority numbers (last)
- [ ] Stories within same tier ordered by epic order
- [ ] Typecheck passes

**Technical Notes:**
- Parse dependency keywords in story titles/descriptions
- Allow manual priority override in story files

**Dependencies:** STORY-010

---

#### STORY-012: Generate Prompt Template

**Epic:** EPIC-003
**Priority:** Must Have
**Points:** 5

**User Story:**
As a developer, I want Ralph to generate prompt.md with all project context so that each Claude iteration understands the codebase.

**Acceptance Criteria:**
- [ ] Creates `ralph/prompt.md` using template structure
- [ ] Includes project overview from product brief
- [ ] Includes architecture patterns and tech stack
- [ ] Includes quality gate commands
- [ ] Includes current sprint/epic context
- [ ] Includes step-by-step task instructions
- [ ] Includes execution rules and signals
- [ ] Includes placeholder for progress context
- [ ] Typecheck passes

**Technical Notes:**
- Template from architecture doc Appendix A
- Balance detail vs context length

**Dependencies:** STORY-011

---

#### STORY-013: Generate Loop Script

**Epic:** EPIC-003
**Priority:** Must Have
**Points:** 8

**User Story:**
As a developer, I want Ralph to generate loop.sh for Claude CLI so that I can run autonomous loops.

**Acceptance Criteria:**
- [ ] Creates `ralph/loop.sh` as executable bash script
- [ ] Uses `claude --print --dangerously-skip-permissions` flags
- [ ] Reads prd.json to find next pending story
- [ ] Invokes Claude with prompt.md content
- [ ] Runs quality gates after each iteration
- [ ] Updates prd.json on story success (passes=true, completedAt)
- [ ] Increments attempts on failure
- [ ] Exits with correct codes (0=complete, 1=stuck, 2=max_iterations, 130=interrupt)
- [ ] Handles Ctrl+C (SIGINT) gracefully
- [ ] Script is portable bash (works on macOS, Linux, WSL)
- [ ] Typecheck passes

**Technical Notes:**
- Include all functions from architecture Interface Design
- Use atomic file updates (temp + mv)
- Test on multiple platforms

**Dependencies:** STORY-012

---

#### STORY-014: Initialize Progress File

**Epic:** EPIC-003
**Priority:** Must Have
**Points:** 2

**User Story:**
As a developer, I want Ralph to initialize progress.txt so that iterations can share learnings with each other.

**Acceptance Criteria:**
- [ ] Creates `ralph/progress.txt` with header section
- [ ] Header includes project name
- [ ] Header includes feature/branch name
- [ ] Header includes start timestamp
- [ ] Uses format from architecture (markdown sections)
- [ ] File is append-only after creation
- [ ] Typecheck passes

**Technical Notes:**
- Template from architecture doc
- Each iteration appends, never overwrites

**Dependencies:** STORY-010

---

### EPIC-004: Loop Execution & Monitoring

**Priority:** Must Have | **FR:** FR-006 | **NFRs:** NFR-001, NFR-002, NFR-003, NFR-004 | **Estimated Points:** 29

---

#### STORY-015: Pre-Execution Summary and Confirmation

**Epic:** EPIC-004
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer, I want Ralph to show a summary and confirm before starting so that I can review the configuration.

**Acceptance Criteria:**
- [ ] Displays stories to implement (count and list)
- [ ] Displays quality gates configured
- [ ] Displays max iterations and stuck threshold
- [ ] Displays branch name (if creating)
- [ ] Asks user to confirm: "Ready to start the loop?"
- [ ] Allows user to cancel and reconfigure
- [ ] Typecheck passes

**Technical Notes:**
- Clear, formatted summary display
- Last chance to catch configuration errors

**Dependencies:** STORY-013, STORY-014

---

#### STORY-016: Loop State Machine Core

**Epic:** EPIC-004
**Priority:** Must Have
**Points:** 8

**User Story:**
As a developer, I want the loop to execute the pick → invoke → verify → update cycle so that stories are implemented automatically.

**Acceptance Criteria:**
- [ ] PICK: Reads prd.json, finds highest priority story where passes=false
- [ ] INVOKE: Calls Claude CLI with prompt.md content
- [ ] VERIFY: Runs quality gates, captures pass/fail status
- [ ] UPDATE: On pass - commits, updates prd.json (passes=true), appends progress.txt
- [ ] UPDATE: On fail - increments attempts, logs failure
- [ ] Loop continues until exit condition
- [ ] Each iteration clearly logged
- [ ] Typecheck passes

**Technical Notes:**
- Core loop from architecture diagram
- State transitions must be atomic

**Dependencies:** STORY-015

---

#### STORY-017: Quality Gate Execution

**Epic:** EPIC-004
**Priority:** Must Have
**Points:** 5

**User Story:**
As a developer, I want quality gates executed after each iteration so that only passing code is committed.

**Acceptance Criteria:**
- [ ] Runs typecheck command if configured
- [ ] Runs test command if configured
- [ ] Runs lint command if configured
- [ ] Runs build command if configured
- [ ] Skips gates with null/empty commands
- [ ] Reports PASS/FAIL for each gate
- [ ] All gates must pass for story success
- [ ] Captures and logs error output on failure
- [ ] Typecheck passes

**Technical Notes:**
- Use run_quality_gate function from architecture
- Continue running all gates even if one fails (report all)

**Dependencies:** STORY-016

---

#### STORY-018: Stuck Detection and Exit Handling

**Epic:** EPIC-004
**Priority:** Must Have
**Points:** 5

**User Story:**
As a developer, I want the loop to stop if stuck so that I don't waste iterations on unsolvable stories.

**Acceptance Criteria:**
- [ ] Tracks consecutive failures per story ID
- [ ] Resets failure count when different story attempted
- [ ] Exits with STUCK (code 1) when attempts >= stuckThreshold
- [ ] Logs clear message: "Story {ID} failed {N} times. May need to be split."
- [ ] Exits with COMPLETE (code 0) when all stories have passes=true
- [ ] Exits with MAX_ITERATIONS (code 2) when limit reached
- [ ] Preserves state on any exit for resumption
- [ ] Typecheck passes

**Technical Notes:**
- Exit codes from architecture doc
- State preserved for debugging and resume

**Dependencies:** STORY-016

---

#### STORY-019: Real-Time Progress Display

**Epic:** EPIC-004
**Priority:** Should Have
**Points:** 3

**User Story:**
As a developer, I want to see real-time progress so that I know what's happening without reading logs.

**Acceptance Criteria:**
- [ ] Shows header bar with project and branch
- [ ] Shows stories progress: "5/24 complete"
- [ ] Shows iteration progress: "8/50"
- [ ] Each iteration labeled: "=== Iteration 8: US-006 - Story Title ==="
- [ ] Quality gate results shown: "Typecheck: PASS | Tests: PASS"
- [ ] Commit hash shown on success
- [ ] Final summary on completion
- [ ] Typecheck passes

**Technical Notes:**
- Format from architecture Interface Design
- Consider terminal width

**Dependencies:** STORY-016

---

#### STORY-020: Loop Resumability

**Epic:** EPIC-004
**Priority:** Should Have
**Points:** 5

**User Story:**
As a developer, I want to resume a stopped loop so that I don't lose progress when interrupted.

**Acceptance Criteria:**
- [ ] Detects existing ralph/prd.json on /ralph invocation
- [ ] Checks if stories remain with passes=false
- [ ] Offers choice: "Resume (5 stories remaining) or start fresh?"
- [ ] Resume skips file generation, goes to execution
- [ ] Resume continues from next pending story
- [ ] Progress.txt context preserved for resumed iterations
- [ ] Typecheck passes

**Technical Notes:**
- Fresh start archives previous run first
- Resume is the happy path for interrupted loops

**Dependencies:** STORY-016

---

### EPIC-005: State Management & Integration

**Priority:** Should Have | **FRs:** FR-007, FR-008, FR-010 | **Estimated Points:** 8

---

#### STORY-021: Archive Previous Run Handling

**Epic:** EPIC-005
**Priority:** Should Have
**Points:** 3

**User Story:**
As a developer, I want previous runs archived so that I don't lose history when starting new features.

**Acceptance Criteria:**
- [ ] Detects existing ralph/prd.json before generation
- [ ] Compares branchName to new feature's branch
- [ ] If different feature: creates archive folder
- [ ] Archive path: `ralph/archive/YYYY-MM-DD-{feature-name}/`
- [ ] Moves prd.json, progress.txt, prompt.md to archive
- [ ] If same feature: asks resume or fresh (STORY-020)
- [ ] Typecheck passes

**Technical Notes:**
- Archives preserve learnings from previous work
- Feature detection by branch name comparison

**Dependencies:** STORY-020

---

#### STORY-022: Sprint Status YAML Updates

**Epic:** EPIC-005
**Priority:** Should Have
**Points:** 3

**User Story:**
As a developer, I want sprint-status.yaml updated as stories complete so that BMAD tracking stays current.

**Acceptance Criteria:**
- [ ] On story pass, updates matching entry in sprint-status.yaml
- [ ] Sets story status to "done"
- [ ] Updates last_updated timestamp
- [ ] Updates sprint metrics (completed, in_progress, not_started counts)
- [ ] Preserves all other sprint-status.yaml content
- [ ] Uses atomic write (temp + mv)
- [ ] Typecheck passes

**Technical Notes:**
- Requires YAML parsing (yq or manual)
- Match by story ID

**Dependencies:** STORY-016

---

#### STORY-023: AGENTS.md Update Instructions

**Epic:** EPIC-005
**Priority:** Should Have
**Points:** 2

**User Story:**
As a developer, I want AGENTS.md updated with learnings so that future iterations and humans benefit from discoveries.

**Acceptance Criteria:**
- [ ] Prompt includes AGENTS.md update instructions
- [ ] Specifies what to add: patterns, gotchas, file locations
- [ ] Instructs Claude to find or create appropriate AGENTS.md
- [ ] Instructions respect existing AGENTS.md structure
- [ ] Append-only (don't rewrite existing content)
- [ ] Typecheck passes

**Technical Notes:**
- Part of prompt.md generation
- Claude decides when updates are warranted

**Dependencies:** STORY-012

---

### EPIC-006: BMAD Workflow Registration

**Priority:** Should Have | **NFR:** NFR-007 | **Estimated Points:** 8

---

#### STORY-024: Create Workflow File Structure

**Epic:** EPIC-006
**Priority:** Should Have
**Points:** 3

**User Story:**
As a BMAD user, I want Ralph registered as a BMAD workflow so that `/workflow-status` shows it as Phase 5.

**Acceptance Criteria:**
- [ ] Creates `~/.claude/config/bmad/modules/bmm/workflows/ralph.md`
- [ ] Workflow follows BMAD workflow file format
- [ ] Includes workflow overview with Goal, Phase, Agent, Inputs, Output
- [ ] References helpers.md for common operations
- [ ] Skill name: `bmad:bmm:ralph`
- [ ] Typecheck passes

**Technical Notes:**
- Structure from BMAD workflow template
- This is the main entry point for /ralph

**Dependencies:** All other stories

---

#### STORY-025: Workflow Status Integration

**Epic:** EPIC-006
**Priority:** Should Have
**Points:** 2

**User Story:**
As a BMAD user, I want Ralph to appear in workflow-status so that I know it's available after sprint planning.

**Acceptance Criteria:**
- [ ] Updates bmm-workflow-status.yaml template to include ralph
- [ ] Ralph listed as Phase 5 workflow
- [ ] Status shows "required" after sprint-planning complete
- [ ] /workflow-status recommends Ralph as next step
- [ ] Typecheck passes

**Technical Notes:**
- Modify BMAD templates
- Add to workflow sequence

**Dependencies:** STORY-024

---

#### STORY-026: Distribution Package and Installer

**Epic:** EPIC-006
**Priority:** Should Have
**Points:** 3

**User Story:**
As a BMAD user, I want to install Ralph from a package so that I can use it in my projects.

**Acceptance Criteria:**
- [ ] Creates distribution folder structure per architecture Appendix B
- [ ] Includes README.md with installation and usage guide
- [ ] Includes install.sh script that copies files correctly
- [ ] Includes all workflow and template files
- [ ] Installation tested on fresh BMAD setup
- [ ] Typecheck passes

**Technical Notes:**
- Package structure from architecture doc
- Test installation in clean environment

**Dependencies:** STORY-024, STORY-025

---

## Sprint Allocation

### Sprint 1 (Weeks 1-2) - 30/30 points

**Goal:** Complete document ingestion and loop configuration interview

**Stories:**

| Story | Title | Points | Priority | Epic |
|-------|-------|--------|----------|------|
| STORY-001 | Read Product Brief Document | 2 | Must Have | EPIC-001 |
| STORY-002 | Parse PRD Document | 3 | Must Have | EPIC-001 |
| STORY-003 | Read Architecture Document | 3 | Must Have | EPIC-001 |
| STORY-004 | Parse Sprint Status YAML | 3 | Must Have | EPIC-001 |
| STORY-005 | Read Individual Story Files | 2 | Must Have | EPIC-001 |
| STORY-006 | Display Documentation Summary | 2 | Must Have | EPIC-002 |
| STORY-007 | Scope Selection Interview | 3 | Must Have | EPIC-002 |
| STORY-008 | Quality Gates Configuration | 3 | Must Have | EPIC-002 |
| STORY-009 | Loop Parameters Configuration | 2 | Must Have | EPIC-002 |
| STORY-010 | Generate prd.json from Selected Stories | 5 | Must Have | EPIC-003 |
| STORY-014 | Initialize Progress File | 2 | Must Have | EPIC-003 |

**Total:** 30 points / 30 capacity (100% utilization)

**Sprint 1 Deliverable:** User can run `/ralph`, see documentation summary, configure loop parameters, and have prd.json + progress.txt generated.

---

### Sprint 2 (Weeks 3-4) - 29/30 points

**Goal:** Complete file generation and implement core loop execution

**Stories:**

| Story | Title | Points | Priority | Epic |
|-------|-------|--------|----------|------|
| STORY-011 | Order Stories by Dependency | 3 | Must Have | EPIC-003 |
| STORY-012 | Generate Prompt Template | 5 | Must Have | EPIC-003 |
| STORY-013 | Generate Loop Script | 8 | Must Have | EPIC-003 |
| STORY-015 | Pre-Execution Summary and Confirmation | 3 | Must Have | EPIC-004 |
| STORY-016 | Loop State Machine Core | 8 | Must Have | EPIC-004 |
| STORY-023 | AGENTS.md Update Instructions | 2 | Should Have | EPIC-005 |

**Total:** 29 points / 30 capacity (97% utilization)

**Sprint 2 Deliverable:** Complete loop file generation (prd.json, prompt.md, loop.sh). Core loop can execute pick → invoke → verify → update cycle.

---

### Sprint 3 (Weeks 5-6) - 32/30 points

**Goal:** Complete execution engine, add state management, register as BMAD workflow

**Stories:**

| Story | Title | Points | Priority | Epic |
|-------|-------|--------|----------|------|
| STORY-017 | Quality Gate Execution | 5 | Must Have | EPIC-004 |
| STORY-018 | Stuck Detection and Exit Handling | 5 | Must Have | EPIC-004 |
| STORY-019 | Real-Time Progress Display | 3 | Should Have | EPIC-004 |
| STORY-020 | Loop Resumability | 5 | Should Have | EPIC-004 |
| STORY-021 | Archive Previous Run Handling | 3 | Should Have | EPIC-005 |
| STORY-022 | Sprint Status YAML Updates | 3 | Should Have | EPIC-005 |
| STORY-024 | Create Workflow File Structure | 3 | Should Have | EPIC-006 |
| STORY-025 | Workflow Status Integration | 2 | Should Have | EPIC-006 |
| STORY-026 | Distribution Package and Installer | 3 | Should Have | EPIC-006 |

**Total:** 32 points / 30 capacity (107% utilization - slight overcommit)

**Sprint 3 Deliverable:** Fully functional Ralph workflow with quality gates, stuck detection, resumability, archiving, and BMAD integration. Ready for distribution.

---

## Epic Traceability

| Epic ID | Epic Name | Stories | Total Points | Sprint(s) |
|---------|-----------|---------|--------------|-----------|
| EPIC-001 | BMAD Document Ingestion | STORY-001 to STORY-005 | 13 | Sprint 1 |
| EPIC-002 | Loop Configuration Interview | STORY-006 to STORY-009 | 10 | Sprint 1 |
| EPIC-003 | Loop File Generation | STORY-010 to STORY-014 | 23 | Sprint 1-2 |
| EPIC-004 | Loop Execution & Monitoring | STORY-015 to STORY-020 | 29 | Sprint 2-3 |
| EPIC-005 | State Management & Integration | STORY-021 to STORY-023 | 8 | Sprint 2-3 |
| EPIC-006 | BMAD Workflow Registration | STORY-024 to STORY-026 | 8 | Sprint 3 |

---

## Functional Requirements Coverage

| FR ID | FR Name | Stories | Sprint |
|-------|---------|---------|--------|
| FR-001 | Document Ingestion | STORY-001 to STORY-005 | 1 |
| FR-002 | User Interview | STORY-006 to STORY-009 | 1 |
| FR-003 | Story Conversion | STORY-010, STORY-011 | 1-2 |
| FR-004 | Prompt Generation | STORY-012 | 2 |
| FR-005 | Loop Script Generation | STORY-013 | 2 |
| FR-006 | Loop Execution | STORY-015 to STORY-020 | 2-3 |
| FR-007 | Sprint Status Updates | STORY-022 | 3 |
| FR-008 | Archive Previous Runs | STORY-021 | 3 |
| FR-009 | Progress File Init | STORY-014 | 1 |
| FR-010 | AGENTS.md Integration | STORY-023 | 2 |

---

## Non-Functional Requirements Coverage

| NFR ID | NFR Name | Stories | Sprint |
|--------|----------|---------|--------|
| NFR-001 | Error Handling | STORY-013, STORY-016, STORY-018 | 2-3 |
| NFR-002 | Stuck Detection | STORY-018 | 3 |
| NFR-003 | Clear Output | STORY-019 | 3 |
| NFR-004 | Resumability | STORY-020, STORY-021 | 3 |
| NFR-005 | Claude CLI Compat | STORY-013, STORY-016 | 2 |
| NFR-006 | Shell Compat | STORY-013 | 2 |
| NFR-007 | BMAD Patterns | STORY-024, STORY-025 | 3 |

---

## Risks and Mitigation

**High:**
- **Large story exceeds context window**
  - Mitigation: Document story sizing guidelines, stuck detection catches it

- **Claude CLI output parsing unreliable**
  - Mitigation: Test with real CLI, use robust regex patterns

**Medium:**
- **YAML parsing complexity in bash**
  - Mitigation: Use yq if available, fallback to simpler parsing

- **Cross-platform bash compatibility**
  - Mitigation: Test on macOS, Linux, WSL; avoid bashisms

**Low:**
- **BMAD template changes**
  - Mitigation: Follow current patterns, update when BMAD updates

---

## Definition of Done

For a story to be considered complete:

- [ ] Code implemented and committed
- [ ] All acceptance criteria satisfied
- [ ] Typecheck passes
- [ ] Tests written and passing (where applicable)
- [ ] Works on macOS (primary platform)
- [ ] Documentation updated (if user-facing)
- [ ] Story file updated with completion notes

---

## Team Capacity

| Metric | Value |
|--------|-------|
| Team Size | 1 developer |
| Sprint Length | 2 weeks |
| Workdays per Sprint | 10 |
| Productive Hours per Day | 6 |
| Total Hours per Sprint | 60 |
| Points per Hour | 2 (senior level) |
| **Capacity per Sprint** | **30 points** |

---

## Next Steps

**Immediate:** Begin Sprint 1

Run `/dev-story STORY-001` to start implementing the first story, or run `/create-story STORY-001` to generate a detailed story document first.

**Sprint Cadence:**
- Sprint 1: Weeks 1-2
- Sprint 2: Weeks 3-4
- Sprint 3: Weeks 5-6

---

**This plan was created using BMAD Method v6 - Phase 4 (Implementation Planning)**

*To continue: Run `/dev-story STORY-001` to begin implementation.*
