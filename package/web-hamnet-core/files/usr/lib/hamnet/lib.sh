# Shared helpers for the HAMNET web UI.
# Sourced by CGI scripts (. /usr/lib/hamnet/lib.sh); not executable on its own.

MENU_DIR=/etc/hamnet/menu.d

# HTML-escape a string for safe output.
hesc() {
	sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# Read the POST body (application/x-www-form-urlencoded) into $POST.
read_post() {
	POST=""
	[ "$REQUEST_METHOD" = "POST" ] && [ -n "$CONTENT_LENGTH" ] && \
		POST="$(head -c "$CONTENT_LENGTH")"
}

# Percent-decode a string. Byte-wise and UTF-8 safe; uses octal escapes
# (\NNN) instead of \xHH so it works across busybox/dash/bash.
urldecode() {
	local data hex
	data="$(printf '%s' "$1" | sed 's/+/ /g')"
	while [ -n "$data" ]; do
		case "$data" in
			%[0-9A-Fa-f][0-9A-Fa-f]*)
				hex="$(printf '%s' "$data" | cut -c2-3)"
				printf "\\$(printf '%03o' "0x$hex")"
				data="$(printf '%s' "$data" | cut -c4-)"
				;;
			*)
				printf '%s' "$(printf '%s' "$data" | cut -c1)"
				data="$(printf '%s' "$data" | cut -c2-)"
				;;
		esac
	done
}

# Percent-encode a string for use in query-string links (byte-wise, UTF-8 safe).
urlencode() {
	local s="$1" i c out=""
	i=1
	while [ "$i" -le "${#s}" ]; do
		c="$(printf '%s' "$s" | cut -c"$i")"
		case "$c" in
			[A-Za-z0-9._-]) out="$out$c" ;;
			*) out="$out$(printf '%%%02X' "'$c")" ;;
		esac
		i=$((i + 1))
	done
	printf '%s' "$out"
}

# Extract a field from urlencoded data: form_get <name> "$POST"
form_get() {
	local key="$1" data="$2" pair
	for pair in $(echo "$data" | tr '&' ' '); do
		case "$pair" in
			"$key"=*) urldecode "${pair#*=}"; return ;;
		esac
	done
}

# Extract a query-string parameter: query_get <name>
query_get() { form_get "$1" "$QUERY_STRING"; }

# Render the navigation bar from the menu.d fragments.
# Each fragment is a single line: "Label|/cgi-bin/target".
render_menu() {
	local f label url
	echo '<nav class="navbar">'
	for f in $(ls "$MENU_DIR" 2>/dev/null | sort); do
		IFS='|' read -r label url < "$MENU_DIR/$f"
		[ -n "$label" ] && [ -n "$url" ] && \
			printf '<a href="%s">%s</a>' "$url" "$(printf '%s' "$label" | hesc)"
	done
	echo '</nav>'
}

# Emit HTTP headers + page head + navigation. Argument: page title.
html_header() {
	printf 'Content-Type: text/html; charset=utf-8\r\n\r\n'
	cat <<HEADER
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>$(printf '%s' "$1" | hesc) — HAMNET</title>
	<link rel="stylesheet" href="/hamnet/style.css">
</head>
<body>
	<header><h1>HAMNET</h1></header>
HEADER
	render_menu
	echo '<main>'
}

# Close the page.
html_footer() {
	cat <<'FOOTER'
</main>
<footer>web-hamnet • OpenWrt</footer>
</body>
</html>
FOOTER
}

# Send an HTTP redirect to a (relative) URL.
redirect() { printf 'Status: 302 Found\r\nLocation: %s\r\n\r\n' "$1"; }
