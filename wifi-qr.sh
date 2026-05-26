#!/usr/bin/env bash
set -euo pipefail

command -v qrencode >/dev/null 2>&1 || {
  echo "qrencode is not installed."
  echo "Install it with:"
  echo "  sudo apt update && sudo apt install qrencode"
  exit 1
}

escape_wifi_field() {
  # Wi-Fi QR fields escape: backslash, semicolon, comma, colon, and double quote
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//;/\\;}"
  s="${s//,/\\,}"
  s="${s//:/\\:}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

slugify_filename() {
  local s="$1"
  s="$(echo "$s" | tr ' /' '__' | tr -cd '[:alnum:]_.-')"
  [[ -n "$s" ]] || s="wifi"
  printf '%s' "$s"
}

echo "Wi-Fi QR Code Generator"
echo "======================"
echo

read -rp "Wi-Fi SSID/name: " ssid

echo
echo "Security type:"
select security_label in \
  "WPA/WPA2 Personal" \
  "WPA2 Personal" \
  "WPA3 Personal" \
  "WPA2/WPA3 Mixed" \
  "WEP" \
  "Open network / no password"
do
  case "$REPLY" in
    1|2|3|4)
      qr_security="WPA"
      break
      ;;
    5)
      qr_security="WEP"
      break
      ;;
    6)
      qr_security="nopass"
      break
      ;;
    *)
      echo "Invalid option. Choose a number from the list."
      ;;
  esac
done

password=""
if [[ "$qr_security" != "nopass" ]]; then
  echo
  read -rsp "Wi-Fi password: " password
  echo
fi

echo
echo "Hidden network?"
select hidden_label in "No" "Yes"; do
  case "$REPLY" in
    1)
      hidden="false"
      break
      ;;
    2)
      hidden="true"
      break
      ;;
    *)
      echo "Invalid option. Choose 1 or 2."
      ;;
  esac
done

echo
echo "Output format:"
select output_format in "PNG" "SVG" "ANSI terminal preview"; do
  case "$REPLY" in
    1)
      format="PNG"
      extension="png"
      qrencode_args=(-o)
      break
      ;;
    2)
      format="SVG"
      extension="svg"
      qrencode_args=(-t SVG -o)
      break
      ;;
    3)
      format="ANSI"
      extension=""
      break
      ;;
    *)
      echo "Invalid option. Choose a number from the list."
      ;;
  esac
done

default_filename="$(slugify_filename "$ssid")-wifi"
if [[ "$format" != "ANSI" ]]; then
  default_filename="${default_filename}.${extension}"

  echo
  read -rp "Output filename [$default_filename]: " output_file
  output_file="${output_file:-$default_filename}"
fi

escaped_ssid="$(escape_wifi_field "$ssid")"
escaped_password="$(escape_wifi_field "$password")"

if [[ "$qr_security" == "nopass" ]]; then
  payload="WIFI:T:nopass;S:${escaped_ssid};H:${hidden};;"
else
  payload="WIFI:T:${qr_security};S:${escaped_ssid};P:${escaped_password};H:${hidden};;"
fi

echo

if [[ "$format" == "ANSI" ]]; then
  qrencode -t ANSIUTF8 "$payload"
  echo
  echo "Generated terminal QR preview."
else
  qrencode "${qrencode_args[@]}" "$output_file" "$payload"
  echo "Created: $output_file"

  if command -v explorer.exe >/dev/null 2>&1; then
    echo
    echo "Open it from WSL with:"
    echo "  explorer.exe \"$output_file\""
  fi
fi

echo
echo "Selected options:"
echo "  SSID: $ssid"
echo "  Security selected: $security_label"
echo "  QR security encoded: $qr_security"
echo "  Hidden: $hidden"
echo "  Format: $format"