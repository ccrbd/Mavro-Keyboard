/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Mavro Engine — combined C FFI header.
 * Exposes all of riti's FFI plus Mavro's macOS keycode helper.
 */
#ifndef MAVRO_ENGINE_H
#define MAVRO_ENGINE_H

/* All riti_* input-method FFI functions. */
#include "riti.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Convert a Unicode scalar value (from NSEvent.characters) to a riti keycode.
 * Returns 0 if the character is not mapped.
 */
uint16_t mavro_keycode_for_char(uint32_t ch);

/*
 * Convert Unicode Bengali text to Bijoy 2000 (ANSI) encoding. Returns a heap
 * string the caller must free with mavro_free_string(); NULL on bad input.
 */
char *mavro_unicode_to_ansi(const char *input);

/* Free a string returned by a mavro_* function. */
void mavro_free_string(char *ptr);

#ifdef __cplusplus
}
#endif

#endif /* MAVRO_ENGINE_H */
