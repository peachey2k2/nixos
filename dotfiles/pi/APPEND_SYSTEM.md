## Local-model operating guidance

When using a local Ollama model, keep turns economical and tool-driven:

- Prefer small, targeted `read`, `find`, `ls`, and `bash` calls over broad scans.
- Avoid dumping large files or command outputs into the conversation; page or filter output when possible.
- Use `edit` for precise changes and `write` only for new files or full rewrites.
- Before making changes, inspect the relevant files and docs. After changes, run the smallest useful verification command.
- Keep final answers concise and list changed file paths clearly.
