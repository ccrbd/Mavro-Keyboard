Mavro Keyboard — native Bengali input method for macOS (Apple Silicon)
======================================================================

TO INSTALL
----------
1. Double-click  "Install Mavro.command".
   • macOS may say it's from an unidentified developer (this build isn't
     notarized yet). If so: right-click the file → Open → Open.
2. Follow the on-screen steps to add "Mavro" in
   System Settings → Keyboard → Input Sources.
3. Switch to Mavro with the Globe/Fn key or Ctrl-Space.
   (First install: if Mavro isn't listed, log out and back in, then retry.)

WHAT IT DOES
------------
• Avro Phonetic typing (type Bengali in Roman letters).
• Two modes — Cmd-Shift-M toggles:
    Preview : dictionary suggestions + autocorrect.
    Raw     : exactly as typed (sOnar→সোনার, moN→মণ), no autocorrect.
• Output encoding — Cmd-Shift-E cycles:
    Unicode → ANSI (SutonnyMJ/classic Bijoy) → ANSI (Kalpurush).
• Tools (menu-bar "ম" menu): Character Map, and a Unicode↔ANSI converter
  (SutonnyMJ both ways; Kalpurush forward).

FONTS
-----
The installer also adds a set of free/open Bengali fonts to ~/Library/Fonts
so Bengali (and the Kalpurush-ANSI output) displays correctly. See
"Font Licenses" for details.

NOTE: SutonnyMJ is NOT bundled — it is proprietary (Bijoy). To view SutonnyMJ
ANSI output you must have SutonnyMJ installed separately. The bundled
Kalpurush ANSI font works out of the box for ANSI (Kalpurush) output.

This build is ad-hoc signed (not notarized) and intended for local sharing.
