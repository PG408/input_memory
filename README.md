# InputMemory

InputMemory is a local macOS menu bar app that records text observable from the foreground focused text input control.

## MVP Scope

- Records focused text-control turns through macOS Accessibility.
- Stores turns in SQLite at `~/Library/Application Support/InputMemory/input_memory.sqlite`.
- Exports the previous day's turns to Markdown in `~/Documents/InputMemory/`.
- Does not record keyboard events, clipboard history, audio, OCR, or LLM summaries.

## Run

```bash
./script/build_and_run.sh
```

## Verify

```bash
swift run InputMemorySelfTest
swift build
```

## Permissions

The app requires macOS Accessibility permission. If permission is missing, the app still opens and shows the permission state, but it does not capture turns.
