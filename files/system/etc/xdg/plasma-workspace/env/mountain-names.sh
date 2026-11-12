# "File Explorer" instead of "Dolphin" in title bars (catalog from files/scripts/explorer-title.sh).
# US English only: any other language the user picked in Settings is left alone.
case ${LANGUAGE:-${LANG:-}} in
  en_US*|C.UTF-8|C.utf8) export LANGUAGE="en@mountain:${LANGUAGE:-en_US}" ;;
esac
