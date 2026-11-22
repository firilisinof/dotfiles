# Note format

Use one subject and one type per note. Project material lives in `projects/<slug>/`, with `<slug>.md` as its overview. Keep current objectives, progress and open questions in `state.md`, decisions and rationale in `decisions.md`, and supporting material alongside. Use `notes/` for standalone knowledge and `plans/` for plans. Match the wiki's language and writing rules. Notes, plans and project files are limited to 4096 bytes each.

Start ordinary notes with YAML fields `created`, `verified`, `description`, `type`, and `tags`. Preserve creation dates. Set verification to the last substantive confirmation or null. Use YYYY-MM-DD. A mechanical move does not reverify the content. Write a one-sentence description ending with a period. Use a small list of meaningful reusable tags or an empty list.

Types are overview, state, rules, prompt, configuration, procedure, finding, research, decisions, plan and reference. Status is current (the default), proposed, or superseded. Research and plan notes must declare it. A state note may include `things_project_id`. Task rules in `global/` declare `applies_to`.

Saved resources belong in `references/<slug>.md`. Their fields are `title`, `url`, `description`, `added` and `tags`. Create or reuse the reference before linking a note to it. Saving a resource does not verify its claims.

Use relative Markdown links, including paths to sibling repositories. Project home links are curated entry points. Keep the plans index maintained by hand; do not generate vault-wide catalogs. Store attachments according to the vault's attachment-storage note.
