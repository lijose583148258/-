# Agent Workflow For FanyiTong

## Why this exists

This project does not need all of `agency-agents`.

It benefits most from a small set of roles that match the real work we are doing:

- mobile feature delivery
- release readiness
- crash and performance diagnosis
- reality-check testing

This file turns those ideas into a practical local workflow for this repository.

## Recommended roles

### 1. Mobile App Builder

Use for:

- Flutter UI implementation
- Android native service work
- input method integration
- accessibility and overlay features

Expected outputs:

- focused code changes
- buildable Android paths
- user-facing interaction improvements

### 2. Reality Checker

Use for:

- asking whether a feature is truly usable on a real phone
- checking whether a "working" prototype actually survives install, launch, permission prompts, and weak network
- forcing the project back to observable behavior instead of assumptions

Expected outputs:

- concrete acceptance checks
- device-first failure reports
- simplified next actions

### 3. Performance Benchmarker

Use for:

- startup lag
- black screen or cold boot issues
- ML Kit warm-up delays
- long-running tasks that need timeout boundaries

Expected outputs:

- measurable timeout limits
- stage-by-stage bottleneck isolation
- logs tied to a single root cause

### 4. Code Reviewer

Use for:

- release risk review
- regression spotting
- native/Flutter integration review before shipping

Expected outputs:

- highest-risk findings first
- missing test coverage
- install/runtime risk notes

## How we should use these roles on this project

### Translate / Conversation / Learn work

Primary role:

- Mobile App Builder

Support roles:

- Code Reviewer
- Reality Checker

Checklist:

- keep the main user path obvious
- verify the page still works on smaller Android phones
- keep high-frequency actions in thumb reach
- avoid adding settings or debug controls to the primary path

### Zalo and chat-assist work

Primary role:

- Mobile App Builder

Support roles:

- Reality Checker
- Code Reviewer

Checklist:

- separate "can read text" from "can act on text"
- prefer insert-ready translation over auto-send
- verify behavior under denied permissions
- verify behavior when Zalo UI changes or text nodes are missing

### Installation and emulator work

Primary role:

- Performance Benchmarker

Support roles:

- Reality Checker

Checklist:

- set explicit timeout per stage
- do not leave background tasks running without feedback
- use one Android SDK path only
- kill stale adb/emulator processes before retrying
- fail fast when acceleration is unavailable

### Release work

Primary role:

- Code Reviewer

Support roles:

- Reality Checker
- Performance Benchmarker

Checklist:

- release APK installs on target devices
- launch path survives first open
- history, storage controls, and settings load without crash
- translation fallback path works when ML Kit is unavailable
- permissions denied path does not crash

## Recommended working order

For most changes in this repo, use this order:

1. Build the feature with Mobile App Builder thinking
2. Run a quick risk pass with Code Reviewer thinking
3. Test the real user path with Reality Checker thinking
4. If startup or install is unstable, switch to Performance Benchmarker thinking

## Current project-specific rules

- Prefer real-device testing over Windows emulator debugging when time is limited.
- Treat emulator setup as infrastructure work, not product validation.
- Do not assume a successful GitHub Actions build means install success on a real phone.
- Any long-running script must have per-stage time limits and visible failure output.
- Any Android troubleshooting must stick to `E:\\android\\Sdk` to avoid mixed-tool conflicts.

## What this means in practice

When we continue developing this app, we should not ask:

- "Which random agent should we use?"

We should ask:

- "Is this a feature task, a release-risk task, or a runtime-diagnosis task?"

Then pick the role:

- feature task -> Mobile App Builder
- install/crash/startup diagnosis -> Performance Benchmarker
- release decision -> Code Reviewer + Reality Checker

## Immediate use on this repository

The next high-value tasks should follow this workflow:

1. Use Reality Checker + Performance Benchmarker to finish install diagnostics on a real device
2. Use Mobile App Builder to refine the chat-assist and history flows
3. Use Code Reviewer to prepare a release-risk pass before wider testing
