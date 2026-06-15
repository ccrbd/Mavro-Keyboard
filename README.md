# Mavro Keyboard

A native **Apple-Silicon** Bengali (Bangla) input method for macOS — a future-proof
replacement for the unmaintained, Intel-only **iAvro**. Mavro brings Avro Phonetic
typing to macOS as a native `arm64` InputMethodKit app, so it stays first-class as
Apple winds Rosetta down.

> Status: **v0.1.0** — working two-mode Avro Phonetic input. See [Roadmap](#roadmap).

## Why

iAvro is an Intel-only build that runs on Apple Silicon only via Rosetta, which Apple
is deprecating. Mavro is built natively and reuses the proven, maintained
[`riti`](https://github.com/OpenBangla/riti) engine (MPL-2.0) that also powers
OpenBangla Keyboard (Linux) and Lekho (macOS), so the hard linguistic logic — Avro
Phonetic transliteration, the dictionary, and autocorrect — is battle-tested rather
than re-derived.

## Features

- **Avro Phonetic** typing (type Bangla in Roman letters), with two modes:
  - **Preview** — Avro-style dictionary suggestions + autocorrect in a candidate window.
  - **Raw** — deterministic, as-typed transliteration with no autocorrect:
    `sonar → সনার`, `sOnar → সোনার`, `mon → মন`, `moN → মণ`.
  - Toggle modes with **⌘⇧M** (or the menu-bar **ম** menu).
- **Output encoding**: Unicode (modern) or **ANSI/Bijoy** (legacy fonts, like Avro's
  "ASCII" output). Toggle with **⌘⇧E**. `ami` → `আমি` (Unicode) / `Avwg` (Bijoy).
- **⌘⇧M / ⌘⇧E work only while Mavro is the active input method** (system-level
  hotkeys), so they never disturb apps' normal ⌘-shortcuts in other input sources.
- **Return** commits the in-progress word *and* sends/newlines in one press.
- On-screen flash confirms each mode/encoding switch (works even when the menu-bar
  icon is hidden behind the notch).
- Custom candidate window (keyboard + mouse selectable).
- **Tools**
  - **Character Map** — click Bengali glyphs to insert them.
  - **Unicode → ANSI (Bijoy) Converter** — convert Unicode Bengali to Bijoy 2000
    (legacy fonts), using the same verified `poriborton` mapping riti uses.
    (Bijoy → Unicode reverse is not yet available — no verified reverse map.)

## Architecture

```
Mavro.app (~/Library/Input Methods/)
  Swift InputMethodKit layer  ──C FFI──►  libmavro_engine.a  ──►  riti (Rust)
```

- `engine/` — Rust crate wrapping `riti`; builds a static lib + C header
  (`mavro_keycode_for_char` + all `riti_*` FFI). Mode toggle maps to riti's
  `phonetic_suggestion` flag.
- `Sources/` — Swift IMK layer: `MavroInputController` (key handling),
  `CandidatePanel` (custom NSPanel), `StatusMenu`, `InputMode`, and `Tools/`.
- `Resources/` — `Info.plist`, entitlements, and the `data/` dictionary files.

Builds with `swiftc` + `cargo` (no Xcode project required).

## Build & install

Requirements: macOS 13+ on Apple Silicon, Rust (`cargo`), and the Xcode Command
Line Tools.

```sh
make install        # build + ad-hoc sign + copy to ~/Library/Input Methods, then launch
```

Then add it: **System Settings → Keyboard → Input Sources → Edit… → +**, pick
**Mavro** (under Bangla), and switch with the Globe/Fn key or Ctrl-Space. On a
first-ever install you may need to log out and back in so macOS registers it.

Other targets: `make build`, `make build-debug`, `make uninstall`, `make clean`.

## Verify

```sh
bash scripts/test_engine.sh   # asserts the four reference conversions in Raw mode
```

## Roadmap

- Bijoy → Unicode (reverse) conversion, once a verified reverse mapping exists.
- Notarized signed distribution (DMG) once feature-complete.
- Polish: preferences, mode-toggle hotkey, menu-bar icon asset.

## License & credits

[MPL-2.0](LICENSE). Built on [`riti`](https://github.com/OpenBangla/riti) by the
OpenBangla project. The macOS InputMethodKit integration patterns (riti FFI
driving, candidate window, cursor-rect fallbacks) are adapted from
[Lekho](https://github.com/ARahim3/Lekho) (MPL-2.0).
