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
