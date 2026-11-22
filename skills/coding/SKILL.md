---
name: coding
description: Implement, review, configure or debug software. Use for repository changes, scripts, refactors and bug fixes that need project conventions and verification.
---

# Coding

Start in the repository. Read its agent instructions, inspect the worktree with `git status --short`, and follow the affected entry point through its callers before editing. Use `rg` to find the implementation and existing tests. Identify the expected behavior and state consequential assumptions. Preserve unrelated edits.

## Make the change

Use established framework paths, types, terminology and tools. Prefer the smallest design that expresses the requirement clearly. Encode invariants in types where practical. Use explicit interface types according to the language's conventions. Give each module one coherent responsibility. Share code where callers genuinely share behavior. Inject a dependency or wrap an external API when it improves isolation, ownership or testing.

Make failures visible. Include the offending input and expected shape when relevant. Spell out ownership, lifetime, concurrency and partial-failure assumptions when they affect correctness. Avoid hidden fallbacks. Use structured JSON for diagnostic logs and plain text for user-facing CLI output.

Keep helpful comments about invariants, proof obligations, upstream bugs and decisions. Update stale ones. Use lowercase inline comments, without terminal punctuation or explanatory colons, except for technical casing. Follow the language's doc-comment convention. Cite the issue or commit when it explains an upstream workaround.

## Verify and deliver

1. Find the documented development environment and checks in the repository's README, build files and CI. Check a tool's subcommand help when its behavior is unclear. Use existing dependencies. Before changing dependencies or environment configuration, tell the user what will change, why and at what scope. Report what changed.
2. Run the project's normal formatter and relevant checks. For a bug fix, add regression coverage. Update affected tests when behavior changes. Keep tests fast, independent, repeatable and self-validating. Use named fakes for external API and database I/O. Isolate filesystem fixtures and remove them afterward.
3. For a simple script, run the script with representative input and inspect its output or built-in checks. Avoid a dedicated test suite for it. For a change that may fail partway, exercise that failure through the normal entry point.
4. Review the diff, fix failures introduced by the change, then report the exact checks run and any outstanding gap.

Read-only Git inspection is fine. Obtain permission for the operation and scope before staging, committing, pushing, stashing, resetting or otherwise changing Git state unless already authorized. The private wiki has a separate standing grant. Use the configured Git identity, concise commits in the repository's style, and no assistant attribution.
