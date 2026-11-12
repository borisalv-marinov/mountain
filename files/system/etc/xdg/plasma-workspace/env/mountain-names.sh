# "File Explorer" instead of "Dolphin" in title bars (catalog from files/scripts/explorer-title.sh).
# US English (or no language set yet, which is English too) only: any other language the user picked is left alone.
# No language set yet (C locale, e.g. a fresh VM): use US English, which Mountain ships. Translations are
# ignored in the C locale, so the title would stay "Dolphin" otherwise.
case ${LANG:-} in
  ""|C|C.UTF-8|C.utf8|POSIX) locale -a 2>/dev/null | grep -qix 'en_US.utf8' && export LANG=en_US.UTF-8 ;;
esac
case ${LANGUAGE:-${LANG:-}} in
  ""|en_US*|C|C.UTF-8|C.utf8|POSIX) export LANGUAGE="en@mountain:${LANGUAGE:-en_US}" ;;
esac
