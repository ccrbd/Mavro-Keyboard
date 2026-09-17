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

/* Unicode -> SutonnyMJ (or back, when `to_unicode`). Expected values were
 * hand-verified by rendering in the SutonnyMJ font. */
static int check_bijoy(const char *in, const char *expected, int to_unicode) {
    char *got = to_unicode ? mavro_bijoy_to_unicode(in) : mavro_unicode_to_bijoy(in);
    int ok = got && strcmp(got, expected) == 0;
    printf("[%s] %s %s -> %s (expected %s)\n", ok ? "PASS" : "FAIL",
           to_unicode ? "bijoy->uni" : "uni->bijoy", in, got ? got : "(null)", expected);
    if (got) mavro_free_string(got);
    return ok;
}

/* iAvro-style mode shows the typed English inline. It relies on riti's
 * auxiliary text being exactly the typed buffer when suggestions are on, and
 * on the phonetic word being among the candidates. */
static int check_iavro(const char *typed, const char *candidate) {
    Config *cfg = riti_config_new();
    riti_config_set_layout_file(cfg, "avro_phonetic");
    riti_config_set_database_dir(cfg, DATA_DIR);
    riti_config_set_user_dir(cfg, USER_DIR);
    riti_config_set_phonetic_suggestion(cfg, true);
    riti_config_set_suggestion_include_english(cfg, false);
    RitiContext *ctx = riti_context_new_with_config(cfg);

    Suggestion *s = NULL;
    for (const char *p = typed; *p; ++p) {
        if (s) riti_suggestion_free(s);
        s = riti_get_suggestion_for_key(ctx, mavro_keycode_for_char((unsigned char)*p), 0, 0);
    }
    int aux_ok = 0, found = 0;
    if (s && !riti_suggestion_is_empty(s) && !riti_suggestion_is_lonely(s)) {
        char *aux = riti_suggestion_get_auxiliary_text(s);
        aux_ok = aux && strcmp(aux, typed) == 0;
        if (aux) riti_string_free(aux);
        for (uintptr_t i = 0; i < riti_suggestion_get_length(s); i++) {
            char *c = riti_suggestion_get_suggestion(s, i);
            if (c && strcmp(c, candidate) == 0) found = 1;
            if (c) riti_string_free(c);
        }
    }
    int ok = aux_ok && found;
    printf("[%s] iavro %s -> inline \"%s\", candidates include %s\n",
           ok ? "PASS" : "FAIL", typed, aux_ok ? typed : "?", found ? candidate : "(missing)");
    if (s) riti_suggestion_free(s);
    riti_context_finish_input_session(ctx);
    riti_context_free(ctx);
    riti_config_free(cfg);
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

    /* SutonnyMJ output — words that rendered wrong before the converter fixes. */
    ok &= check_bijoy("হয়ে", "n‡q", 0);
    ok &= check_bijoy("দিল্লি", "w`wjø", 0);
    ok &= check_bijoy("অসন্তোষ", "Am‡šÍvl", 0);
    ok &= check_bijoy("বিস্তারিত", "we¯ÍvwiZ", 0);
    ok &= check_bijoy("সিদ্ধান্ত", "wm×všÍ", 0);
    ok &= check_bijoy("কে", "†K", 0);        /* word committed alone: leading e-kar form */
    ok &= check_bijoy("গ্রাম", "MÖvg", 0);    /* ro-fola */
    ok &= check_bijoy("MÖvg", "গ্রাম", 1);

    ok &= check_iavro("ami", "আমি");
    ok &= check_iavro("bangla", "বাংলা");

    printf("\n%s\n", ok ? "ALL PASS" : "SOME FAILED");
    return ok ? 0 : 1;
}
