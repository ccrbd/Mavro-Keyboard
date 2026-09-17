Mavro Keyboard — Bangla (Avro Phonetic) typing for macOS on Apple Silicon
=========================================================================

Replaces iAvro, which no longer runs on new macOS. Needs an Apple Silicon Mac
(M1 or newer) with macOS 13 or later.


HOW TO INSTALL
--------------
This build isn't notarized by Apple yet, so macOS will block a plain
double-click the first time. Use ONE of these two ways.

A) Terminal — easiest, no security prompts
   1. Keep this "Mavro Keyboard" window open.
   2. Open Terminal (press Cmd-Space, type Terminal, press Return).
   3. Type  bash  followed by a space (don't press Return yet).
   4. Drag "Install Mavro.command" from this window into the Terminal window.
   5. Press Return and wait for "=== Done ===".

B) Double-click
   1. Double-click "Install Mavro.command". macOS says it was "Not Opened".
      Click Done.
   2. Open System Settings -> Privacy & Security, scroll down to Security,
      and click "Open Anyway" next to "Install Mavro.command".
   3. Enter your Mac password, then click "Open Anyway" once more.

The installer adds Mavro to your input sources automatically.
Switch to it with the Globe (fn) key or Control-Space and start typing.

If Mavro doesn't show up in the input menu:
   System Settings -> Keyboard -> Text Input -> Input Sources -> Edit... -> "+"
   -> Bangla -> Mavro -> Add. If it isn't in the list, log out and back in.

You can remove the old "Avro Keyboard" (iAvro) from Input Sources.


HOW TO TYPE
-----------
Typing modes — press Cmd-Shift-M to switch:

  iAvro style (default)
     Works like iAvro: the English you type stays underlined in the text,
     Bangla suggestions appear below it.
       Space          use the highlighted suggestion (adds a space)
       Return         use it and press Return (sends the message) in one go
       Up / Down      choose a different suggestion
       Left / Right   use it and move the cursor
       Esc            cancel the word
     Mavro remembers the suggestion you pick for each word.

  Preview
     The Bangla word is shown in the text; suggestions are numbered.
     Tab / Shift-Tab or 1-9 choose.

  Raw
     Exactly as typed, no dictionary or autocorrect:
     sonar -> সনার,  sOnar -> সোনার,  mon -> মন,  moN -> মণ

Output — press Cmd-Shift-E to switch:
  Unicode (normal)  ->  ANSI SutonnyMJ / Bijoy  ->  ANSI Kalpurush

Both shortcuts only work while Mavro is your active keyboard, so your other
apps' Cmd shortcuts are unaffected.

Tools are in the "ম" menu in the menu bar: Character Map, and a Unicode <->
ANSI converter.


FONTS
-----
The installer also adds free Bangla fonts (Kalpurush, Siyam Rupali, Noto Sans /
Serif Bengali, Hind Siliguri, Tiro Bangla, and more) — see "Font Licenses".
SutonnyMJ is NOT included (it's a paid Bijoy font). To read SutonnyMJ ANSI
text you need SutonnyMJ installed; the included "Kalpurush ANSI" font reads
ANSI Kalpurush output.
