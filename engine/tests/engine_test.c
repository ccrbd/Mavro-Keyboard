/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Drives the Mavro engine (riti via our static lib) exactly like the Swift
 * InputMethodKit layer does, and checks the user's reference conversions in
 * Raw mode (phonetic_suggestion = false). Build/run via scripts/test_engine.sh.
 */
#include <stdio.h>
#include <string.h>
#include "mavro_engine.h"

static const char *DATA_DIR;
static const char *USER_DIR;

/* Feed an ASCII word to a fresh raw-mode context and return the pre-edit text
 * (the building transliteration) after the last key, copied into `out`. */
static void transliterate_raw(const char *word, char *out, size_t out_sz) {
    Config *cfg = riti_config_new();
    riti_config_set_layout_file(cfg, "avro_phonetic");
    riti_config_set_database_dir(cfg, DATA_DIR);
    riti_config_set_user_dir(cfg, USER_DIR);
    riti_config_set_phonetic_suggestion(cfg, false); /* RAW mode */
    riti_config_set_suggestion_include_english(cfg, true);

    RitiContext *ctx = riti_context_new_with_config(cfg);

    out[0] = '\0';
    Suggestion *sugg = NULL;
    for (const char *p = word; *p; ++p) {
        unsigned char c = (unsigned char)*p;
        uint16_t key = mavro_keycode_for_char((uint32_t)c);
        uint8_t mod = (c >= 'A' && c <= 'Z') ? MODIFIER_SHIFT : 0;
        if (sugg) { riti_suggestion_free(sugg); sugg = NULL; }
        sugg = riti_get_suggestion_for_key(ctx, key, mod, 0);
    }

    if (sugg && !riti_suggestion_is_empty(sugg)) {
        char *txt = riti_suggestion_get_pre_edit_text(sugg, 0);
        if (txt) {
            strncpy(out, txt, out_sz - 1);
            out[out_sz - 1] = '\0';
            riti_string_free(txt);
        }
    }
    if (sugg) riti_suggestion_free(sugg);
    riti_context_finish_input_session(ctx);
    riti_context_free(ctx);
    riti_config_free(cfg);
}

static int check(const char *word, const char *expected) {
    char got[256];
    transliterate_raw(word, got, sizeof got);
    int ok = strcmp(got, expected) == 0;
    printf("[%s] %-7s -> %s (expected %s)\n", ok ? "PASS" : "FAIL", word, got, expected);
    return ok;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s <data_dir> <user_dir>\n", argv[0]);
        return 2;
    }
    DATA_DIR = argv[1];
    USER_DIR = argv[2];

    int ok = 1;
    ok &= check("sonar", "সনার");          /* সনার */
    ok &= check("sOnar", "সোনার");    /* সোনার */
    ok &= check("mon",   "মন");                       /* মন */
    ok &= check("moN",   "মণ");                       /* মণ */

    printf("\n%s\n", ok ? "ALL PASS" : "SOME FAILED");
    return ok ? 0 : 1;
}
