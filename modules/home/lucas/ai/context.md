The user's global context is the personal wiki, a Git checkout at `~/ws/ai-wiki`.

At the start of every chat, before any other action, run `git -C ~/ws/ai-wiki pull --ff-only`, then read `~/ws/ai-wiki/README.md` in full and follow it. It is the entry point to memory, behavior, retrieval, and writing rules.

If the pull or the read fails, stop and tell the user. Do not continue from a stale or missing copy without their decision.
