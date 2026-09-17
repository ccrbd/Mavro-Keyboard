// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Mavro Engine — wraps the riti Bengali input method library for use from the
// macOS InputMethodKit (Swift) layer.
//
// riti exposes a C FFI (`riti_*` functions, see include/riti.h). Linking this
// crate as a static library pulls in all of riti's `#[no_mangle] extern "C"`
// symbols, so the Swift side can call them directly. On top of that we add one
// macOS-specific helper: translating a typed character into a riti keycode.
//
// The keycode mapping mirrors the canonical mapping used by Lekho (MPL-2.0),
// since the target values are fixed by riti's `keycodes` module.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

// Force riti to be linked so its FFI symbols are included in the static lib.
extern crate riti;

pub use riti::keycodes;

/// Convert Unicode Bengali text to Bijoy 2000 (ANSI/Windows-1252) encoding, for
/// the standalone converter tool. Uses the same `poriborton` crate riti uses for
/// its ANSI typing output, so results match. Returns a heap string the caller
/// must free with `mavro_free_string`. Returns NULL on bad UTF-8.
#[no_mangle]
pub extern "C" fn mavro_unicode_to_ansi(input: *const c_char) -> *mut c_char {
    if input.is_null() {
        return std::ptr::null_mut();
    }
    let text = match unsafe { CStr::from_ptr(input) }.to_str() {
        Ok(t) => t,
        Err(_) => return std::ptr::null_mut(),
    };
    // poriborton's map keys the PRECOMPOSED nukta letters (য় U+09DF, ড় U+09DC,
    // ঢ় U+09DD), which are Unicode composition-exclusions — NFC would wrongly
    // decompose them. Recompose just those three sequences so both precomposed
    // and decomposed input convert correctly.
    let recomposed = recompose_nukta(text);
    let converted = poriborton::bijoy2000::unicode_to_bijoy(&recomposed);
    match CString::new(converted) {
        Ok(c) => c.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Recompose the three Bengali nukta letters from a base + U+09BC sequence into
/// their precomposed code points (which poriborton's map expects). Precomposed
/// input passes through unchanged.
fn recompose_nukta(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    let mut chars = input.chars().peekable();
    while let Some(c) = chars.next() {
        if chars.peek() == Some(&'\u{09BC}') {
            let composed = match c {
                '\u{09A1}' => Some('\u{09DC}'), // ড + ় -> ড়
                '\u{09A2}' => Some('\u{09DD}'), // ঢ + ় -> ঢ়
                '\u{09AF}' => Some('\u{09DF}'), // য + ় -> য়
                _ => None,
            };
            if let Some(rc) = composed {
                out.push(rc);
                chars.next(); // consume the nukta
                continue;
            }
        }
        out.push(c);
    }
    out
}

// --- SutonnyMJ / classic Bijoy conversion -----------------------------------
//
// Ported from the verified bijoyconverter.com mapping (its ordered
// {ascii, unicode} list). The algorithm is a sequential substring replace in
// list order (longest/most-specific combinations first, which is how kar
// reordering is handled). The patches on top (ro-fola, word-initial vowel
// signs, EXTRA_PRE/POST, reorder_fix) mirror the ANSI-Unicode-Doc-Converter
// project's src/convert.js, verified there against real documents.

use std::collections::HashSet;
use std::sync::OnceLock;
use unicode_normalization::UnicodeNormalization;

/// Legacy glyph patches applied before the main table (ANSI -> Unicode). Wins
/// over the bare `w` (i-kar) rule so the cluster reorders correctly.
const EXTRA_PRE: &[(&str, &str)] = &[("w\u{00B4}", "\u{0995}\u{09CD}\u{09AE}\u{09BF}")]; // w´ -> ক্মি

/// Standalone leftover glyphs cleaned up after the main table (ANSI -> Unicode).
const EXTRA_POST: &[(&str, &str)] = &[
    ("\u{00B4}", "\u{0995}\u{09CD}\u{09AE}"), // ´ -> ক্ম
    ("\u{00D1}", "\u{2014}"),                 // Ñ -> — (em dash)
    ("\u{0192}", "\u{09C2}"),                 // ƒ -> ূ
    ("\u{00A4}", "\u{09AE}"),                 // ¤ -> ম
    ("\u{00AF}", "\u{09B8}"),                 // ¯ -> স
];

/// Whitespace as JavaScript's `\s` defines it, so the word-initial vowel-sign
/// rule matches the reference implementation exactly.
fn is_js_whitespace(c: char) -> bool {
    matches!(
        c,
        '\t' | '\n' | '\u{000B}' | '\u{000C}' | '\r' | ' ' | '\u{00A0}' | '\u{1680}'
            | '\u{2000}'..='\u{200A}' | '\u{2028}' | '\u{2029}' | '\u{202F}' | '\u{205F}'
            | '\u{3000}' | '\u{FEFF}'
    )
}

/// Bengali consonants incl. nukta letters and khanda-ta (reph cluster detection).
fn is_consonant(c: char) -> bool {
    matches!(c, '\u{0995}'..='\u{09B9}' | '\u{09DC}'..='\u{09DF}' | '\u{09CE}')
}

static BIJOY_TABLE_JSON: &str = include_str!("bijoy_table.json");

/// Returns the ordered (unicode, ascii) mapping pairs, parsed once.
fn bijoy_table() -> &'static Vec<(String, String)> {
    static TABLE: OnceLock<Vec<(String, String)>> = OnceLock::new();
    TABLE.get_or_init(|| {
        let parsed: serde_json::Value =
            serde_json::from_str(BIJOY_TABLE_JSON).unwrap_or(serde_json::Value::Null);
        let mut pairs = Vec::new();
        if let Some(arr) = parsed.as_array() {
            for item in arr {
                if let (Some(ascii), Some(unicode)) = (
                    item.get("ascii").and_then(|v| v.as_str()),
                    item.get("unicode").and_then(|v| v.as_str()),
                ) {
                    pairs.push((unicode.to_string(), ascii.to_string()));
                }
            }
        }
        pairs
    })
}

fn unicode_to_sutonnymj(input: &str) -> String {
    // NFC first (e.g. ে+া -> ো), then recompose the nukta letters NFC leaves split.
    let normalized: String = input.nfc().collect();
    let mut s = recompose_nukta(&normalized);
    for (unicode, ascii) in bijoy_table() {
        if s.contains(unicode.as_str()) {
            s = s.replace(unicode.as_str(), ascii);
        }
    }
    // Ro-fola: the flat table emits "ª", but SutonnyMJ renders ্র as "Ö"
    // (গ্র -> MÖ). "ª" is exclusively ro-fola in the table, so this is safe.
    s = s.replace('\u{00AA}', "\u{00D6}");
    // Word-initial e-kar/ai-kar take the leading glyph form ("‡"->"†", "‰"->"ˆ")
    // at the start of the string OR after whitespace. The string-start case
    // matters for typing, where each word is converted on its own at commit.
    let mut out = String::with_capacity(s.len());
    let mut prev: Option<char> = None;
    for c in s.chars() {
        let word_initial = prev.map_or(true, is_js_whitespace);
        out.push(match c {
            '\u{2021}' if word_initial => '\u{2020}',
            '\u{2030}' if word_initial => '\u{02C6}',
            _ => c,
        });
        prev = Some(c);
    }
    out
}

fn sutonnymj_to_unicode(input: &str) -> String {
    if input.is_empty() {
        return String::new();
    }
    // Same fast-reject as the reference: skip pairs whose first char isn't in
    // the original input (no rule ever introduces an ASCII byte).
    let present: HashSet<char> = input.chars().collect();
    let first_present = |key: &str| key.chars().next().map_or(false, |c| present.contains(&c));

    let mut s = input.to_string();
    for (ascii, unicode) in EXTRA_PRE {
        if first_present(ascii) && s.contains(ascii) {
            s = s.replace(ascii, unicode);
        }
    }
    for (unicode, ascii) in bijoy_table() {
        if first_present(ascii) && s.contains(ascii.as_str()) {
            s = s.replace(ascii.as_str(), unicode.as_str());
        }
    }
    for (ascii, unicode) in EXTRA_POST {
        if first_present(ascii) && s.contains(ascii) {
            s = s.replace(ascii, unicode);
        }
    }
    reorder_fix(&s)
}

/// Unicode-level reordering the flat table can't resolve (ANSI -> Unicode):
/// chandrabindu after the vowel sign, অ+া -> আ, split ো/ৌ recombined, and a
/// reph stored after its cluster moved in front of it.
fn reorder_fix(input: &str) -> String {
    // 1. ঁ + vowel sign -> vowel sign + ঁ   (পঁুথি -> পুঁথি)
    let mut s = String::with_capacity(input.len());
    let mut chars = input.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\u{0981}' {
            if let Some(&k) = chars.peek() {
                if matches!(k, '\u{09BE}'..='\u{09CC}' | '\u{09D7}') {
                    s.push(k);
                    s.push(c);
                    chars.next();
                    continue;
                }
            }
        }
        s.push(c);
    }
    // 2-4. অ+া -> আ, ে+া -> ো, ে+ৗ -> ৌ
    let s = s
        .replace("\u{0985}\u{09BE}", "\u{0986}")
        .replace("\u{09C7}\u{09BE}", "\u{09CB}")
        .replace("\u{09C7}\u{09D7}", "\u{09CC}");
    // 5. Reph: CLUSTER + র্ (not followed by a consonant) -> র্ + CLUSTER
    if s.contains("\u{09B0}\u{09CD}") {
        move_trailing_reph(&s)
    } else {
        s
    }
}

/// Emulates the reference regex
/// `(C(?:্C)*)র্(?!C)` -> `র্$1` (greedy, left-to-right, non-overlapping).
fn move_trailing_reph(input: &str) -> String {
    let v: Vec<char> = input.chars().collect();
    let mut out = String::with_capacity(input.len());
    let mut i = 0;
    while i < v.len() {
        if is_consonant(v[i]) {
            // Longest run of "্C" pairs after the leading consonant.
            let mut pairs = 0;
            while i + 2 + 2 * pairs < v.len()
                && v[i + 1 + 2 * pairs] == '\u{09CD}'
                && is_consonant(v[i + 2 + 2 * pairs])
            {
                pairs += 1;
            }
            // Backtrack from the greediest cluster until "র্" (not before a
            // consonant) follows it.
            let matched = (0..=pairs).rev().find_map(|k| {
                let end = i + 1 + 2 * k;
                let is_reph = end + 1 < v.len() && v[end] == '\u{09B0}' && v[end + 1] == '\u{09CD}';
                let followed_by_consonant = end + 2 < v.len() && is_consonant(v[end + 2]);
                (is_reph && !followed_by_consonant).then_some(end)
            });
            if let Some(end) = matched {
                out.push('\u{09B0}');
                out.push('\u{09CD}');
                out.extend(&v[i..end]);
                i = end + 2;
                continue;
            }
        }
        out.push(v[i]);
        i += 1;
    }
    out
}

fn to_c_string(s: String) -> *mut c_char {
    match CString::new(s) {
        Ok(c) => c.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Convert Unicode Bengali to SutonnyMJ / classic Bijoy ANSI. Caller frees with
/// `mavro_free_string`; NULL on bad input.
#[no_mangle]
pub extern "C" fn mavro_unicode_to_bijoy(input: *const c_char) -> *mut c_char {
    if input.is_null() {
        return std::ptr::null_mut();
    }
    match unsafe { CStr::from_ptr(input) }.to_str() {
        Ok(t) => to_c_string(unicode_to_sutonnymj(t)),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Convert SutonnyMJ / classic Bijoy ANSI back to Unicode Bengali. Caller frees
/// with `mavro_free_string`; NULL on bad input.
#[no_mangle]
pub extern "C" fn mavro_bijoy_to_unicode(input: *const c_char) -> *mut c_char {
    if input.is_null() {
        return std::ptr::null_mut();
    }
    match unsafe { CStr::from_ptr(input) }.to_str() {
        Ok(t) => to_c_string(sutonnymj_to_unicode(t)),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Free a string returned by `mavro_*` functions.
#[no_mangle]
pub extern "C" fn mavro_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

/// Convert a character (from `NSEvent.characters`, as a Unicode scalar value)
/// into the riti keycode the engine expects. Returns 0 for unmapped characters.
///
/// Shift-modified letters map to the dedicated `VC_*_SHIFT` codes, because Avro
/// Phonetic treats e.g. `O` and `o` as different inputs (ো-kar vs the vowel),
/// which is exactly what drives the user's "raw mode" examples
/// (`sOnar → সোনার`, `moN → মণ`).
#[no_mangle]
pub extern "C" fn mavro_keycode_for_char(ch: u32) -> u16 {
    use riti::keycodes::*;
    match char::from_u32(ch) {
        Some('`') => VC_GRAVE,
        Some('~') => VC_TILDE,
        Some('1') => VC_1,
        Some('2') => VC_2,
        Some('3') => VC_3,
        Some('4') => VC_4,
        Some('5') => VC_5,
        Some('6') => VC_6,
        Some('7') => VC_7,
        Some('8') => VC_8,
        Some('9') => VC_9,
        Some('0') => VC_0,
        Some('!') => VC_EXCLAIM,
        Some('@') => VC_AT,
        Some('#') => VC_HASH,
        Some('$') => VC_DOLLAR,
        Some('%') => VC_PERCENT,
        Some('^') => VC_CIRCUM,
        Some('&') => VC_AMPERSAND,
        Some('*') => VC_ASTERISK,
        Some('(') => VC_PAREN_LEFT,
        Some(')') => VC_PAREN_RIGHT,
        Some('-') => VC_MINUS,
        Some('_') => VC_UNDERSCORE,
        Some('=') => VC_EQUALS,
        Some('+') => VC_PLUS,
        Some('a') => VC_A,
        Some('b') => VC_B,
        Some('c') => VC_C,
        Some('d') => VC_D,
        Some('e') => VC_E,
        Some('f') => VC_F,
        Some('g') => VC_G,
        Some('h') => VC_H,
        Some('i') => VC_I,
        Some('j') => VC_J,
        Some('k') => VC_K,
        Some('l') => VC_L,
        Some('m') => VC_M,
        Some('n') => VC_N,
        Some('o') => VC_O,
        Some('p') => VC_P,
        Some('q') => VC_Q,
        Some('r') => VC_R,
        Some('s') => VC_S,
        Some('t') => VC_T,
        Some('u') => VC_U,
        Some('v') => VC_V,
        Some('w') => VC_W,
        Some('x') => VC_X,
        Some('y') => VC_Y,
        Some('z') => VC_Z,
        Some('A') => VC_A_SHIFT,
        Some('B') => VC_B_SHIFT,
        Some('C') => VC_C_SHIFT,
        Some('D') => VC_D_SHIFT,
        Some('E') => VC_E_SHIFT,
        Some('F') => VC_F_SHIFT,
        Some('G') => VC_G_SHIFT,
        Some('H') => VC_H_SHIFT,
        Some('I') => VC_I_SHIFT,
        Some('J') => VC_J_SHIFT,
        Some('K') => VC_K_SHIFT,
        Some('L') => VC_L_SHIFT,
        Some('M') => VC_M_SHIFT,
        Some('N') => VC_N_SHIFT,
        Some('O') => VC_O_SHIFT,
        Some('P') => VC_P_SHIFT,
        Some('Q') => VC_Q_SHIFT,
        Some('R') => VC_R_SHIFT,
        Some('S') => VC_S_SHIFT,
        Some('T') => VC_T_SHIFT,
        Some('U') => VC_U_SHIFT,
        Some('V') => VC_V_SHIFT,
        Some('W') => VC_W_SHIFT,
        Some('X') => VC_X_SHIFT,
        Some('Y') => VC_Y_SHIFT,
        Some('Z') => VC_Z_SHIFT,
        Some('[') => VC_BRACKET_LEFT,
        Some(']') => VC_BRACKET_RIGHT,
        Some('\\') => VC_BACK_SLASH,
        Some('{') => VC_BRACE_LEFT,
        Some('}') => VC_BRACE_RIGHT,
        Some('|') => VC_BAR,
        Some(';') => VC_SEMICOLON,
        Some('\'') => VC_APOSTROPHE,
        Some(',') => VC_COMMA,
        Some('.') => VC_PERIOD,
        Some('/') => VC_SLASH,
        Some(':') => VC_COLON,
        Some('"') => VC_QUOTE,
        Some('<') => VC_LESS,
        Some('>') => VC_GREATER,
        Some('?') => VC_QUESTION,
        _ => 0,
    }
}
