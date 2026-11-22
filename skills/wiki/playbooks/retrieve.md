# Retrieve

From the wiki root, read each applicable task rule in full. The `applies_to` field selects coding (implement, review, configure, debug), plotting, tasks, mail, calendar, or web (read a page or extract it). For example:

```sh
rg -l -U '^applies_to:\n(  - .+\n)*  - coding\n' global
```

For a known project read `projects/<slug>/<slug>.md`, its current rules and decisions in full, and its state note when present. Find a project by listing the descriptions in `projects/*/*.md` whose filename matches its directory. Search supporting notes inside that project first. Search in English, preserve literal identifiers and broaden the terms within scope before reporting an unsuccessful search. Read the relevant notes in full. Use `notes/` for standalone subjects.

Read applicable instructions in their own words. Supporting knowledge may be summarized. Skip superseded history unless the question needs it. Search saved references only on request. Load a role prompt only when the requested behavior matches. For plans, follow the links in `plans/index.md`. For next steps, consult project state and the authorized task system.
