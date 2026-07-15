# Tool Constraints & File Modification Rules

## 1. File Modification and Creation
- NEVER use the `bash` tool to create or edit code files (e.g., do not use `cat <<EOF`, `echo`, `sed`, or redirections like `>` or `>>`).
- To **create** a new file or completely overwrite a file, you MUST use the `write` tool.
- To **edit or patch** an existing file, you MUST use the `edit` tool to apply targeted search-and-replace patches. 

## 2. Execution and Debugging Loop
- Only use the `bash` tool to **execute, test, or lint** the code (e.g., `python script.py`).
- If execution fails or returns a syntax/runtime error:
  1. DO NOT rewrite or overwrite the entire file.
  2. Use the `read` tool to inspect the exact lines where the error occurred.
  3. Use the `edit` tool to patch only the broken lines.
  4. Run the code again using `bash`.
- Keep the debug loop targeted, surgical, and minimal.

## 3. using python to debug
- Only write to a file and edit this file if being reused
- run that file with python
- never stdin cat to python to run a debug program
