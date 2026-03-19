---
name: Direct file edits only
description: Always use the Edit tool directly for .luau files — never use Python scripts or Bash workarounds
type: feedback
---

Always use the Edit tool directly to modify .luau files. Do not use Python scripts or Bash workarounds for file editing.

**Why:** User was frustrated when Python was used to edit Lua files — it's unnecessarily complex and error-prone. The Edit tool works fine.

**How to apply:** When editing any file in this project, use the Edit tool. If it fails, adjust the old_string to match better rather than switching to Python.
