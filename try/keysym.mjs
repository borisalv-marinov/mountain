// X11 keysym for one character (pass a whole code point, not a UTF-16 unit).
export function charToKeysym(ch) {
  const cp = ch.codePointAt(0);
  if (cp === 0x0a) return 0xff0d; // Return
  if (cp === 0x09) return 0xff09; // Tab
  if ((cp >= 0x20 && cp <= 0x7e) || (cp >= 0xa0 && cp <= 0xff)) return cp;
  return 0x01000000 + cp;
}
// Characters that need Shift held on a US keyboard: the VNC server maps a keysym to a key and does not add Shift by itself (> & | _ ~ $ arrived as . 7 \ - ` 4).
export function needsShift(ch) { return /^[A-Z~!@#$%^&*()_+{}|:"<>?]$/.test(ch); }
