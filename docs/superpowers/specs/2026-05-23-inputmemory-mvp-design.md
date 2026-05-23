# InputMemory MVP Design

Date: 2026-05-23

## 1. Executive Summary

InputMemory is a macOS menu bar app that records text observable from the foreground focused text input control. The MVP does not record keyboard events, clipboard history, audio, screen pixels, or LLM summaries. Its purpose is to preserve local evidence of what the user typed or otherwise caused to appear in foreground text controls, then export the previous day's records as Markdown for later LLM consumption.

The primary success criterion is text recall. It is acceptable for a turn boundary to be coarse. It is not acceptable to lose text merely because the app tried to infer a precise semantic boundary.

## 2. Non-Goals

The MVP does not implement:

- LLM memory summarization.
- Clipboard recording.
- Keyboard event logging.
- OCR or screen recording.
- Input audio capture or speech recognition.
- Sensitive-content filtering.
- App blacklist or password-field exclusion.
- Editing or deleting captured records.
- Startup at login.
- Real-time session management as a behavior boundary.

## 3. Core Concepts

### 3.1 Turn

A turn is the primary fact record. It represents one observable interaction period with a focused text-like control.

A turn contains:

- One user-text field: `observed_text`.
- Context metadata captured when the turn is closed.
- Capture state metadata.
- Lifecycle metadata.

The turn is the source of truth. Session is only a derived grouping for display and export.

### 3.2 Observed Text

`observed_text` is the only field that stores user input text.

Its semantic definition is:

`observed_text` is the most recent non-empty text value successfully read from the active turn's focused text control. If the turn never produced a non-empty text value, `observed_text` is an empty string.

The overwrite priority is:

1. If the current text read is non-empty, overwrite `observed_text`.
2. If the current text read is empty, do not overwrite an existing non-empty `observed_text`.
3. If the turn never produced a non-empty text value, keep `observed_text = ""`.
4. If non-empty text becomes empty, flush the current turn, set `ended_empty = true`, and end the turn with `end_reason = text_cleared`.

This rule handles chat boxes and search boxes that clear after submission without requiring the app to infer whether a message was actually sent.

### 3.3 Session

Session is not a runtime boundary for capture. It is a derived grouping used in the viewer and Markdown export.

Sessions are computed from completed turns by grouping on:

- `app_name`
- `bundle_id`
- `window_title`

The app does not maintain a real-time session state machine. App switching can end a turn, but it does not create a session object during capture.

App name, bundle id, window title, and session grouping are recorded from the context being left when the turn closes. They are metadata for the turn and must not drive turn splitting, except that foreground app switching closes the active turn because the active input target is no longer observable.

## 4. Capture Scope

The MVP monitors only:

- The foreground app.
- The currently focused text-like accessibility element.

The MVP records all readable text-like controls without sensitive-content filtering. This is intentionally broad for the prototype and carries privacy risk.

## 5. Capture Strategy

The capture mechanism is hybrid:

- Use `NSWorkspace` notifications for foreground app changes.
- Use macOS Accessibility APIs to inspect focused elements and read text values.
- Use Accessibility notifications where reliable, especially for focus or value changes.
- Use polling as a fallback to reduce missed input.

Polling is dynamic:

- Idle with no active turn: 1000 ms.
- Active turn: 500 ms.
- Recently changed text: 300 ms.

Additional recall protections:

- When focus enters a text-like control, read immediately.
- When an Accessibility value-change notification fires, read immediately.
- When the first non-empty text is read, update memory and flush promptly.
- When text transitions from non-empty to empty, flush immediately and end the turn.

## 6. Text Control Detection

The MVP optimizes for coverage.

Standard matches include:

- `AXTextField`
- `AXTextArea`
- `AXComboBox`
- `AXSearchField`
- Web or Electron editable text areas when exposed through Accessibility

Heuristic matches include focused elements with evidence such as:

- String `AXValue`
- `AXSelectedText`
- `AXSelectedTextRange`
- Editable attributes
- Role descriptions suggesting text, edit, input, or search

Non-text controls are ignored. If an element appears to be a text control but cannot be read, record an unreadable turn.

Relevant metadata:

- `control_role`
- `control_subrole`
- `control_title`
- `control_description`
- `control_path_hint`
- `control_frame`
- `control_fingerprint`
- `is_heuristic_text_control`

Runtime identity uses the Accessibility element reference. Persisted identity uses `control_fingerprint`.

## 7. Turn Lifecycle

### 7.1 Turn Creation

When focus enters a readable or suspected text control:

1. Create an in-memory `ActiveTurn`.
2. Immediately attempt the first text read.
3. Insert the database row only after the first read result is known.

First read outcomes:

- Non-empty text: insert row with `observed_text = current_text`, `capture_status = readable`.
- Empty text: insert row with `observed_text = ""`, `capture_status = empty`.
- Unreadable text-like control: insert row with `observed_text = ""`, `capture_status = unreadable`.

If focus leaves before the first read completes, no database row is required.

### 7.2 Turn Update

The app keeps the active turn in memory. Capture reads compare against in-memory state, not database state.

The database receives throttled overwrite updates:

- First non-empty text: flush promptly.
- Non-empty text changes: update the in-memory turn and flush according to adaptive throttling.
- Empty read after non-empty: do not clear `observed_text`; update state metadata.
- Non-empty-to-empty transition: flush immediately and end the turn.

### 7.3 Turn End Conditions

A turn ends when any of the following occurs:

- Foreground app changes.
- Focus changes to another control.
- Text transitions from non-empty to empty.
- The current control disappears or becomes inaccessible.
- No text change occurs for 120 seconds.
- Recording is paused.
- App exits or shuts down.

For app switch and focus switch, the turn context belongs to the old app/control being left, not to the newly entered context. The app does not store start-window and end-window history for a turn; it stores the final context snapshot used to classify that turn.

### 7.4 Shutdown and Recovery

On normal app shutdown:

- Flush the active turn.
- Set `ended_at`.
- Set `end_reason = app_shutdown`.

On next launch:

- Find rows with `ended_at IS NULL`.
- Set `ended_at = last_observed_at`.
- Set `end_reason = crash_unclosed`.

## 8. Storage

### 8.1 Primary Store

SQLite is the primary store.

Default path:

`~/Library/Application Support/InputMemory/input_memory.sqlite`

SQLite is used because the app needs reliable local writes, overwrite updates, viewer queries, and deterministic Markdown export.

### 8.2 Turn Fields

The MVP can start with one main table: `turns`.

Recommended columns:

- `id`
- `observed_text`
- `observed_text_hash`
- `observed_text_length`
- `app_name`
- `bundle_id`
- `window_title`
- `control_role`
- `control_subrole`
- `control_title`
- `control_description`
- `control_path_hint`
- `control_frame`
- `control_fingerprint`
- `is_heuristic_text_control`
- `capture_status`
- `ended_empty`
- `ever_had_non_empty_text`
- `started_at`
- `last_observed_at`
- `ended_at`
- `end_reason`
- `created_at`
- `updated_at`

`observed_text` is the only column that stores user input text. Other columns are metadata.

### 8.3 Runtime State

The capture loop must not repeatedly read SQLite.

The active turn is held in memory with fields such as:

- `turn_id`
- `observed_text`
- `last_raw_text`
- `has_non_empty_text`
- `ended_empty`
- `capture_status`
- `last_observed_at`
- `dirty`
- `last_flushed_at`

SQLite reads are for viewer queries, export, and startup recovery.

## 9. Markdown Export

Markdown is a generated view, not the source of truth.

Default export path:

`~/Documents/InputMemory/`

Export behavior:

- T day trigger exports T-1 day.
- Manual export and scheduled export share the same export date rule.
- The file is named `YYYY-MM-DD.md`.
- Export overwrites the existing file for that date.
- Export includes all turns without filtering, including empty and unreadable turns.
- Export groups turns by derived session: app + bundle id + window title.
- Turn text is wrapped in a `text` fenced block.

The MVP includes:

- User-configurable daily export time.
- Manual `Export Now`.

The MVP does not include continuous or incremental export.

## 10. Menu Bar App and Viewer

InputMemory is a macOS menu bar app.

The menu bar provides:

- Recording state.
- Pause.
- Resume.
- Export Now.
- Open viewer.
- Quit.

The viewer provides:

- Current Accessibility permission status.
- Current recording state.
- Current focus/capture status.
- Recent turns list.
- Turn preview in the list.
- Full `observed_text` in a scrollable detail area.
- Daily export time setting.

The MVP viewer does not support editing, deletion, or filtering.

## 11. Permissions

The MVP requires Accessibility permission.

Behavior:

- If not authorized, the app still runs.
- The menu bar and viewer show that permission is required.
- The viewer provides a button to open System Settings.
- No turns are created without permission.
- After authorization, recording can start.

Input Monitoring permission is not an MVP requirement.

## 12. Pause and Resume

Pause behavior:

- Flush the current active turn.
- End it with `end_reason = paused`.
- Stop the capture loop.

Resume behavior:

- Restart capture.
- Re-detect foreground app and focused control.
- Create a new turn if the focused element qualifies.

## 13. Risks and Known Limitations

Accessibility behavior differs across apps. Some apps may expose only partial text or no text at all.

Fast input and immediate submission can still be missed if no Accessibility notification fires and the full action completes between polling intervals.

Large text controls may create expensive reads. The MVP mitigates this through adaptive flushing and UI previews, but it still preserves full text in SQLite and Markdown.

The MVP intentionally captures all readable text-like controls and does not filter sensitive content. This creates privacy and security risk and should be revisited before wider distribution.

Derived session grouping may be noisy because window titles can change frequently. This is acceptable because session is only a classification layer.

## 14. Accepted Decisions

- App name: InputMemory.
- Primary goal: maximize captured text recall.
- Core entity: turn.
- Session: derived grouping by app and window title.
- Text field: one user-text field, `observed_text`.
- `observed_text`: most recent non-empty text; empty reads do not overwrite non-empty text.
- Non-empty-to-empty: end turn with `end_reason = text_cleared`.
- Idle timeout: 120 seconds.
- Capture: hybrid Accessibility notifications plus dynamic polling.
- Clipboard: not recorded.
- Keyboard events: not recorded.
- Sensitive filtering: not in MVP.
- Primary store: SQLite.
- Export: Markdown, T day exports T-1 day, overwrite generated file.
- UI: menu bar app plus minimal viewer.
- Startup at login: not in MVP.
