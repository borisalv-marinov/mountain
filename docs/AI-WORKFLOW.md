# How AI builds Mountain (and keeps usage low)

Paste the **Session prompt** below at the start of every new Claude Code session in this folder.

---

## Session prompt

```
You are building Mountain, a BlueBuild Linux image on top of Bazzite.
The owner is not a programmer: explain results in plain words, no jargon.

READ FIRST, ONLY THESE:
- docs/AI-WORKFLOW.md (this file)
- docs/superpowers/plans/2026-11-10-mountain-phases.md: read Global Constraints,
  Review Focus, and ONLY the task you are working on.
- docs/TESTING.md: the "Progress" section, to see which task is next.
Do not read other files unless the current task lists them.

TODAY'S TASK: Task <N>.  (If I don't say, take the first unchecked task in Progress.)

HOW TO WORK:
1. Use superpowers:subagent-driven-development to run the task.
   - Implementer subagent: model haiku. Give it only the task text, Global
     Constraints and the file paths. Nothing else.
   - Reviewer subagent: model sonnet. It checks the diff against the task and
     Global Constraints.
   - You (the main session) plan, hand out work and decide. You never do bulk
     edits or long file reads yourself.
2. If ponytail is installed: use it during implementation. Write the smallest
   change that passes the task's check. No extra features, files or abstractions.
3. Test before claiming done (superpowers:verification-before-completion):
   - Run tests/check-flathub-ids.sh locally if Flatpak IDs changed.
   - Push to branch mountain-phases, then check CI ONCE with
     `gh run list -L 1`, and again only when I ask. If it failed,
     `gh run view --log-failed | tail -80`. Never read full logs.
   - On a CI failure use superpowers:systematic-debugging. Find the cause
     before changing anything. At most 2 fix attempts, then stop and tell me.
4. Research rule: before using any package name, service name, file path or
   module option you are not 100% sure of, verify it (one web search
   "standard", or check the Bazzite/BlueBuild docs). Write the source URL
   in the commit message.
5. When CI is green: tick the task in docs/TESTING.md Progress, then give me the
   manual VM checklist for that task in 5 lines or fewer.
6. One task per session. When it's done, stop and tell me to start a fresh session.

SAFETY:
- Never commit cosign.key, ISOs or VM disks.
- Never use bazzite testing/unstable tags.
- Never push to main. Only the owner merges.
- End commit messages with:
  Co-Authored-By: Claude <noreply@anthropic.com>

OUTPUT: short. Result first. No recaps of files you wrote.
```

---

## Why this saves usage

| Habit | Saving |
|---|---|
| **One task per session**, starting fresh | Long chats re-send all old history on every message. This is the biggest saving. |
| **Cheap models do the work**: Haiku edits, Sonnet reviews, the expensive model only coordinates | Haiku costs a fraction of Opus |
| **Read only the current task**, not the whole plan | Less text loaded |
| **CI logs: last 80 lines only** | Build logs are huge |
| **Check CI once, not in a loop** | Each check costs a message |
| **Ponytail** (writes less code) | Independent tests show about 10–25% cost saving, not 50% |
| **Short answers** | Less output |

## Ponytail

Not installed yet. It's a third-party plugin, and several different GitHub copies exist, so the owner must approve the exact source before it's installed. Until then, rule 2 in the prompt does the same job: smallest change that passes.

## Picking the model in the app

- **Simple tasks (1–6):** set the session to Sonnet. Haiku helpers do the edits.
- **Risky tasks (7 and 9):** Opus for the main session, Haiku helpers.
