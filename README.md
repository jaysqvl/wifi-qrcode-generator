# Wi-Fi QR Code Generator

An interactive Bash script that creates QR codes for Wi-Fi networks. It asks for
the network details, validates the required fields, and generates a QR code that
phones and other devices can scan to join the network. You can run it fully
interactively or pass options for quicker repeatable runs.

## Features

- Friendly interactive prompts with sensible defaults.
- Optional command-line flags for common one-liners.
- Supports WPA/WPA2/WPA3 personal networks, WEP, and open networks.
- Includes a hidden-network option.
- Generates PNG or SVG files, or prints an ANSI terminal preview.
- Requires SSID and password input when the selected security type needs them.
- Warns when a WPA password is shorter than the usual 8-character minimum.
- Adds the selected file extension when you leave it off.
- Infers PNG or SVG format from `--output` when the extension is present.
- Protects existing files unless you confirm interactively or pass `--force`.
- Creates output directories when needed.
- Escapes special characters in network names and passwords for Wi-Fi QR payloads.
- Includes `--help` for quick usage details.

## Requirements

- Bash
- `qrencode`

On Ubuntu or WSL, install `qrencode` with:

```sh
sudo apt update && sudo apt install qrencode
```

## Usage

Make the script executable:

```sh
chmod +x wifi-qr.sh
```

Run it:

```sh
./wifi-qr.sh
```

With no options, the script asks for each value:

1. Enter the Wi-Fi SSID/name.
2. Choose the security type. Press Enter to use the default WPA/WPA2/WPA3 option.
3. Enter the password, unless the network is open.
4. Choose whether the network is hidden. Press Enter for `No`.
5. Choose PNG, SVG, or an ANSI terminal preview. Press Enter for PNG.
6. For PNG or SVG output, accept the default filename or enter your own.

For help:

```sh
./wifi-qr.sh --help
```

## Command-line Options

You can pass options instead of answering every prompt:

```sh
./wifi-qr.sh --ssid "Guest WiFi" --password "secret123"
```

When `--ssid` is provided, omitted non-secret choices use these defaults. A
WPA/WEP password is still required and will be prompted for if omitted.

- Security: `wpa`
- Hidden network: `false`
- Format: `png`
- Output file: based on the SSID, for example `Guest_WiFi-wifi.png`

Common examples:

```sh
# Create a PNG for a WPA/WPA2/WPA3 network.
./wifi-qr.sh --ssid "Guest WiFi" --password "secret123"

# Create an SVG with a custom filename. The .svg extension is added if omitted.
./wifi-qr.sh --ssid "Office" --password "secret123" --format svg --output office-qr

# Print an open network QR code in the terminal.
./wifi-qr.sh --ssid "Cafe WiFi" --open --format ansi

# Overwrite an existing output file.
./wifi-qr.sh --ssid "Guest WiFi" --password "secret123" --output guest.png --force
```

Supported options:

```text
-s, --ssid VALUE        Wi-Fi network name.
-p, --password VALUE    Wi-Fi password for WPA/WEP networks.
-t, --security VALUE    Security type: wpa, wep, or nopass.
    --open              Shortcut for --security nopass.
    --hidden            Mark the network as hidden.
    --visible           Mark the network as visible.
    --format VALUE      Output format: png, svg, or ansi.
-o, --output FILE       Output filename for PNG/SVG.
-f, --force             Overwrite an existing output file.
-h, --help              Show help.
```

For private networks, omit `--password` if you do not want the password saved in
your shell history. The script will prompt for it without echoing it.

## Output

For PNG and SVG output, the default filename is based on the SSID, followed by
`-wifi`, for example:

```text
MyNetwork-wifi.png
MyNetwork-wifi.svg
```

If you enter a filename without the selected extension, the script adds it:

```text
guest-network
guest-network.png
```

If you pass `--output guest.svg` without `--format`, the script infers SVG. If
you pass an output filename with no extension, PNG is used unless you choose SVG
with `--format svg`.

If the output file already exists, interactive mode asks before overwriting it.
Command-line mode exits instead, unless you pass `--force`. If you enter a path
to a directory that does not exist, the script creates that directory.

Generated `*.png` and `*.svg` files are ignored by Git so local QR codes are not
committed accidentally.

When running in WSL, the script prints an `explorer.exe` command after creating a
file so you can open the generated QR code from Windows.

## Notes

The Wi-Fi QR payload format uses `WPA` for WPA, WPA2, WPA3, and mixed personal
networks. That is expected and works for typical home and guest networks.

Use the terminal preview for a quick check. Use PNG or SVG when you want to save,
share, print, or scan the QR code from another device.

`--output` is only valid with PNG and SVG output. Terminal preview writes the QR
code directly to your terminal.

## Troubleshooting

### `qrencode is not installed.`

Install `qrencode`:

```sh
sudo apt update && sudo apt install qrencode
```

### Invalid menu choice

Enter the number shown next to the option you want, or press Enter to accept the
default. The script will keep asking until a valid option is selected.

### Password prompt appears blank

Password input is hidden while you type. Press Enter when you are done.

### Output file already exists

Run the script again with a different filename, confirm the overwrite prompt in
interactive mode, or pass `--force` when using command-line options.

### QR code does not scan

Try generating a PNG or SVG file instead of using the terminal preview, then scan
the file from another screen or print it. Also confirm that the SSID, password,
security type, and hidden-network setting match the router configuration.

## License

See [LICENSE](LICENSE).
