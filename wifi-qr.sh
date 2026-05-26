#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="${0##*/}"

ssid=""
password=""
security=""
hidden=""
format=""
output_file=""
force=false
interactive_mode=false

trap 'echo; echo "Cancelled."; exit 130' INT

show_help() {
  cat <<EOF
Wi-Fi QR Code Generator

Usage:
  ./$SCRIPT_NAME [options]

Interactive:
  ./$SCRIPT_NAME

Examples:
  ./$SCRIPT_NAME
  ./$SCRIPT_NAME --ssid "Guest WiFi" --security wpa --password "secret123" --output guest.png
  ./$SCRIPT_NAME --ssid "Cafe" --open --format ansi

Options:
  -s, --ssid VALUE        Wi-Fi network name.
  -p, --password VALUE    Wi-Fi password for WPA/WEP networks.
  -t, --security VALUE    Security type: wpa, wep, or nopass.
      --open             Shortcut for --security nopass.
      --hidden           Mark the network as hidden.
      --visible          Mark the network as visible.
      --format VALUE     Output format: png, svg, or ansi.
  -o, --output FILE       Output filename for PNG/SVG.
  -f, --force             Overwrite an existing output file.
  -h, --help              Show this help.

With no SSID option, the script asks for everything interactively. When --ssid is
provided, omitted security, visibility, format, and filename use common defaults.

Requirements:
  qrencode

Install on Ubuntu or WSL:
  sudo apt update && sudo apt install qrencode
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

need_value() {
  local option="$1"
  local value="${2-}"

  [[ -n "$value" ]] || die "$option requires a value."
}

normalize_security() {
  local value="${1,,}"

  case "$value" in
    wpa|wpa2|wpa3|wpa-personal|wpa2-personal|wpa3-personal|mixed|wpa-mixed)
      printf 'wpa'
      ;;
    wep)
      printf 'wep'
      ;;
    open|none|nopass|no-pass|no_password|no-password)
      printf 'nopass'
      ;;
    *)
      die "Unsupported security type: $1. Use wpa, wep, or nopass."
      ;;
  esac
}

security_label() {
  case "$1" in
    wpa)
      printf 'WPA/WPA2/WPA3 Personal'
      ;;
    wep)
      printf 'WEP'
      ;;
    nopass)
      printf 'Open network / no password'
      ;;
  esac
}

qr_security_value() {
  case "$1" in
    wpa)
      printf 'WPA'
      ;;
    wep)
      printf 'WEP'
      ;;
    nopass)
      printf 'nopass'
      ;;
  esac
}

normalize_format() {
  local value="${1,,}"

  case "$value" in
    png)
      printf 'png'
      ;;
    svg)
      printf 'svg'
      ;;
    ansi|term|terminal|preview)
      printf 'ansi'
      ;;
    *)
      die "Unsupported output format: $1. Use png, svg, or ansi."
      ;;
  esac
}

format_label() {
  case "$1" in
    png)
      printf 'PNG'
      ;;
    svg)
      printf 'SVG'
      ;;
    ansi)
      printf 'ANSI terminal preview'
      ;;
  esac
}

infer_format_from_output() {
  local file="${1,,}"

  case "$file" in
    *.png)
      printf 'png'
      ;;
    *.svg)
      printf 'svg'
      ;;
    *)
      return 1
      ;;
  esac
}

parse_args() {
  local option

  while (($#)); do
    option="$1"
    case "$option" in
      -h|--help)
        show_help
        exit 0
        ;;
      -s|--ssid)
        need_value "$option" "${2-}"
        ssid="$2"
        shift 2
        ;;
      --ssid=*)
        ssid="${option#*=}"
        [[ -n "$ssid" ]] || die "--ssid requires a value."
        shift
        ;;
      -p|--password)
        need_value "$option" "${2-}"
        password="$2"
        shift 2
        ;;
      --password=*)
        password="${option#*=}"
        [[ -n "$password" ]] || die "--password requires a value."
        shift
        ;;
      -t|--security|--type)
        need_value "$option" "${2-}"
        security="$(normalize_security "$2")"
        shift 2
        ;;
      --security=*|--type=*)
        security="$(normalize_security "${option#*=}")"
        shift
        ;;
      --open|--nopass|--no-password)
        security="nopass"
        shift
        ;;
      --hidden)
        hidden="true"
        shift
        ;;
      --visible|--not-hidden)
        hidden="false"
        shift
        ;;
      --format)
        need_value "$option" "${2-}"
        format="$(normalize_format "$2")"
        shift 2
        ;;
      --format=*)
        format="$(normalize_format "${option#*=}")"
        shift
        ;;
      -o|--output)
        need_value "$option" "${2-}"
        output_file="$2"
        shift 2
        ;;
      --output=*)
        output_file="${option#*=}"
        [[ -n "$output_file" ]] || die "--output requires a value."
        shift
        ;;
      -f|--force)
        force=true
        shift
        ;;
      --)
        shift
        (($# == 0)) || die "Unexpected argument: $1"
        ;;
      *)
        show_help >&2
        echo >&2
        die "Unknown option: $option"
        ;;
    esac
  done
}

require_qrencode() {
  command -v qrencode >/dev/null 2>&1 || {
    echo "qrencode is not installed." >&2
    echo "Install it with:" >&2
    echo "  sudo apt update && sudo apt install qrencode" >&2
    exit 1
  }
}

escape_wifi_field() {
  # Wi-Fi QR fields escape: backslash, semicolon, comma, colon, and double quote.
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
  s="$(printf '%s' "$s" | tr ' /' '__' | tr -cd '[:alnum:]_.-')"
  [[ -n "$s" ]] || s="wifi"
  printf '%s' "$s"
}

prompt_required() {
  local prompt="$1"
  local value

  while true; do
    printf '%s' "$prompt" >&2
    IFS= read -r value || die "Input cancelled."

    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return
    fi

    echo "This value is required." >&2
  done
}

prompt_secret_required() {
  local prompt="$1"
  local value

  while true; do
    printf '%s' "$prompt" >&2
    IFS= read -rs value || die "Input cancelled."
    echo >&2

    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return
    fi

    echo "This value is required." >&2
  done
}

choose_option() {
  local title="$1"
  local default="$2"
  shift 2

  local options=("$@")
  local choice
  local choice_number
  local i
  local default_label

  while true; do
    echo >&2
    echo "$title" >&2

    for i in "${!options[@]}"; do
      default_label=""
      if (( i + 1 == default )); then
        default_label=" (default)"
      fi
      printf '  %d) %s%s\n' "$((i + 1))" "${options[$i]}" "$default_label" >&2
    done

    printf 'Choose [%d]: ' "$default" >&2
    IFS= read -r choice || die "Input cancelled."
    choice="${choice:-$default}"

    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      choice_number=$((10#$choice))
      if (( choice_number >= 1 && choice_number <= ${#options[@]} )); then
        printf '%s' "$choice_number"
        return
      fi
    fi

    echo "Invalid option. Choose a number from 1 to ${#options[@]}." >&2
  done
}

prompt_yes_no() {
  local prompt="$1"
  local default="$2"
  local answer
  local suffix

  case "$default" in
    y|Y)
      suffix="Y/n"
      ;;
    n|N)
      suffix="y/N"
      ;;
    *)
      die "Invalid yes/no default: $default"
      ;;
  esac

  while true; do
    printf '%s [%s]: ' "$prompt" "$suffix" >&2
    IFS= read -r answer || die "Input cancelled."
    answer="${answer:-$default}"

    case "${answer,,}" in
      y|yes)
        return 0
        ;;
      n|no)
        return 1
        ;;
      *)
        echo "Please answer yes or no." >&2
        ;;
    esac
  done
}

with_extension() {
  local file="$1"
  local extension="$2"

  [[ -n "$file" ]] || die "Output filename cannot be empty."

  if [[ "${file,,}" != *."$extension" ]]; then
    file="${file}.${extension}"
  fi

  printf '%s' "$file"
}

prepare_output_file() {
  local file="$1"
  local extension="$2"
  local allow_prompt="$3"
  local parent_dir

  file="$(with_extension "$file" "$extension")"
  parent_dir="$(dirname -- "$file")"

  if [[ ! -d "$parent_dir" ]]; then
    if [[ "$allow_prompt" == "true" ]]; then
      echo "Directory does not exist: $parent_dir" >&2
      prompt_yes_no "Create it?" "y" || return 1
    fi

    mkdir -p -- "$parent_dir" || die "Could not create directory: $parent_dir"
    echo "Created directory: $parent_dir" >&2
  fi

  [[ -w "$parent_dir" ]] || die "Directory is not writable: $parent_dir"

  if [[ -e "$file" && "$force" != "true" ]]; then
    if [[ "$allow_prompt" == "true" ]]; then
      prompt_yes_no "File exists. Overwrite $file?" "n" || return 1
    else
      die "Output file exists: $file. Use --force to overwrite it."
    fi
  fi

  printf '%s' "$file"
}

prompt_output_file() {
  local default_file="$1"
  local extension="$2"
  local file
  local prepared_file

  while true; do
    echo >&2
    printf 'Output filename [%s]: ' "$default_file" >&2
    IFS= read -r file || die "Input cancelled."
    file="${file:-$default_file}"

    if prepared_file="$(prepare_output_file "$file" "$extension" true)"; then
      printf '%s' "$prepared_file"
      return
    fi
  done
}

choose_security() {
  local choice

  choice="$(choose_option \
    "Security type:" \
    1 \
    "WPA/WPA2/WPA3 Personal" \
    "WEP" \
    "Open network / no password")"

  case "$choice" in
    1)
      printf 'wpa'
      ;;
    2)
      printf 'wep'
      ;;
    3)
      printf 'nopass'
      ;;
  esac
}

choose_format() {
  local choice

  choice="$(choose_option \
    "Output format:" \
    1 \
    "PNG file" \
    "SVG file" \
    "ANSI terminal preview")"

  case "$choice" in
    1)
      printf 'png'
      ;;
    2)
      printf 'svg'
      ;;
    3)
      printf 'ansi'
      ;;
  esac
}

build_payload() {
  local qr_security="$1"
  local escaped_ssid
  local escaped_password

  escaped_ssid="$(escape_wifi_field "$ssid")"
  escaped_password="$(escape_wifi_field "$password")"

  if [[ "$qr_security" == "nopass" ]]; then
    printf 'WIFI:T:nopass;S:%s;H:%s;;' "$escaped_ssid" "$hidden"
  else
    printf 'WIFI:T:%s;S:%s;P:%s;H:%s;;' "$qr_security" "$escaped_ssid" "$escaped_password" "$hidden"
  fi
}

parse_args "$@"

if [[ -z "$ssid" ]]; then
  interactive_mode=true
fi

if [[ -z "$format" && -n "$output_file" ]]; then
  if inferred_format="$(infer_format_from_output "$output_file")"; then
    format="$inferred_format"
  fi
fi

require_qrencode

echo "Wi-Fi QR Code Generator"
echo "======================"
echo

if [[ -z "$ssid" ]]; then
  ssid="$(prompt_required "Wi-Fi SSID/name: ")"
fi

[[ -n "$ssid" ]] || die "SSID cannot be empty."

if [[ -z "$security" ]]; then
  if [[ "$interactive_mode" == "true" ]]; then
    security="$(choose_security)"
  else
    security="wpa"
  fi
fi

if [[ "$security" == "nopass" ]]; then
  if [[ -n "$password" ]]; then
    echo "Open network selected; ignoring password." >&2
  fi
  password=""
else
  if [[ -z "$password" ]]; then
    echo
    password="$(prompt_secret_required "Wi-Fi password: ")"
  fi

  while [[ "$security" == "wpa" && ${#password} -lt 8 ]]; do
    echo "WPA passwords are usually at least 8 characters." >&2
    prompt_yes_no "Continue with this password?" "n" && break
    password="$(prompt_secret_required "Wi-Fi password: ")"
  done
fi

if [[ -z "$hidden" ]]; then
  if [[ "$interactive_mode" == "true" ]]; then
    echo
    if prompt_yes_no "Hidden network?" "n"; then
      hidden="true"
    else
      hidden="false"
    fi
  else
    hidden="false"
  fi
fi

if [[ -z "$format" ]]; then
  if [[ "$interactive_mode" == "true" ]]; then
    format="$(choose_format)"
  else
    format="png"
  fi
fi

if [[ "$format" == "ansi" && -n "$output_file" ]]; then
  die "--output cannot be used with --format ansi."
fi

if [[ "$format" != "ansi" ]]; then
  extension="$format"
  default_filename="$(slugify_filename "$ssid")-wifi.${extension}"

  if [[ -n "$output_file" ]]; then
    output_file="$(prepare_output_file "$output_file" "$extension" false)"
  elif [[ "$interactive_mode" == "true" ]]; then
    output_file="$(prompt_output_file "$default_filename" "$extension")"
  else
    output_file="$(prepare_output_file "$default_filename" "$extension" false)"
  fi
fi

qr_security="$(qr_security_value "$security")"
payload="$(build_payload "$qr_security")"

echo

if [[ "$format" == "ansi" ]]; then
  qrencode -t ANSIUTF8 "$payload" || die "Failed to generate terminal QR preview."
  echo
  echo "Generated terminal QR preview."
else
  qrencode_args=(-o)
  if [[ "$format" == "svg" ]]; then
    qrencode_args=(-t SVG -o)
  fi

  qrencode "${qrencode_args[@]}" "$output_file" "$payload" || die "Failed to create QR code."
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
echo "  Security selected: $(security_label "$security")"
echo "  QR security encoded: $qr_security"
echo "  Hidden: $hidden"
echo "  Format: $(format_label "$format")"
if [[ "$format" != "ansi" ]]; then
  echo "  Output: $output_file"
fi
