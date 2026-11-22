---
name: things
description: Consult Things for project next steps, outstanding work, priorities, or task status. Use when someone asks what to do next, requests a to-do, or finishes work tracked in Things.
---

# Things

For "what's next for this project?", read the project's private wiki home and state. They explain the objective, constraints and open decisions. Then read the corresponding Things list for actionable work and completion. Identify the next open task that advances the objective and explain why. Distinguish a suggestion from an agreed task. If the sources disagree on a decision that matters, ask.

## Find the right list

Use the installed `things` on the Mac or via the Pi5 shell. Start with the state's `things_project_id` if present. Otherwise match the project in the first command and use its ID or a unique ID prefix in the second.

```sh
things --json projects
things --json project "$project_id"
things --json show "$task_id"
```

For an individual to-do use `things find "$text"`. For a time-based request choose `things today` or `things upcoming`. Capture the command's exit status before filtering its output. Exit 3 means the CLI returned cached data after a failed sync. Label it as cached. Report other access failures.

## Change a task

- Create a task with the user's consent. An explicit request to add it supplies consent. Use `things new "$title" --in "$project_id"` for an existing list. Ask before creating a project. An unanswered suggestion can remain a proposal in the wiki.
- When you deliver the outcome an existing task asks for, use `things mark --done "$task_id"` and tell the user. Leave partially completed work open and explain what remains. Routine consultation authorizes no other edits.
- Check `things --help` for views and exit codes, or `things project --help`, `things new --help` and `things mark --help` for arguments.
