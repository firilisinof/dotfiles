# Vendored skills

Imported skills are regular directories in this library. [vendor-lock.json](vendor-lock.json) records their source repository, pinned revision, upstream file hashes, and local changes. Each imported skill includes its upstream license.

To update an import:

1. Select an upstream revision and compare its skill files with the pinned revision.
2. Copy changes to the selected skills and their references. Preserve the local changes listed in the lock file, including invocation policy and agent metadata.
3. Copy the current upstream license into each imported skill.
4. Update the revision and upstream hashes in the lock file. Hash the upstream files before local edits.
5. Validate frontmatter, agent metadata, relative reference links, and examples. Check CLI instructions against the installed application's help.
