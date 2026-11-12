# "File Explorer" instead of "Dolphin" in title bars (catalog from files/scripts/explorer-title.sh).
# US English (or no language set yet, which is English too) only: any other language the user picked is left alone.
case ${LANGUAGE:-${LANG:-}} in
  ""|en_US*|C|C.UTF-8|C.utf8|POSIX) export LANGUAGE="en@mountain:${LANGUAGE:-en_US}" ;;
esac
