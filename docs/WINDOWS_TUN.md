# Simorgh VPN — Windows TUN setup

The Windows desktop client uses the `flutter_vless` Windows backend for a full-system IPv4 tunnel (Xray + tun2socks + Wintun). Android and iOS continue to use the existing `flutter_v2ray` backend.

## Runtime files required

The Windows backend does not download executable files automatically. Before running or packaging the Windows app, place these x64 files in a folder named `xray` beside the built application executable:

```text
Simorgh VPN/
  simorgh_vpn.exe
  xray/
    xray.exe
    tun2socks.exe
    wintun.dll
    geoip.dat       # only if a profile uses GeoIP rules
    geosite.dat     # only if a profile uses GeoSite rules
```

Sources:
- `xray.exe`: official Xray-core Windows x64 release archive: https://github.com/XTLS/Xray-core/releases
- `tun2socks.exe`: Windows amd64 release from: https://github.com/xjasonlyu/tun2socks/releases
- `wintun.dll`: official Wintun AMD64 package: https://www.wintun.net/

Use trusted upstream releases and verify their signatures/checksums where provided. Keep `wintun.dll` beside `tun2socks.exe`.

## Build

Run PowerShell or Command Prompt as Administrator when testing full-tunnel mode:

```powershell
flutter pub get
flutter run -d windows
```

For a release build:

```powershell
flutter build windows --release
```

Copy the `xray` folder beside the generated executable under `build\windows\x64\runner\Release\` (or the equivalent output directory for your Flutter version).

## Important behavior

- Full-tunnel mode requires Administrator privileges.
- The Windows backend establishes an IPv4 TUN path and protects DNS/IPv6 according to the plugin's Windows implementation.
- A successful start request is not itself proof of a live tunnel. The UI changes to connected only after the native backend reports `CONNECTED`.
- If the app or native workers crash, the backend may retain its Windows Filtering Platform traffic barrier. Reopen Simorgh VPN as Administrator and explicitly disconnect to clear the retained policy.
- Isolated server ping is not currently supported by the Windows backend; the ping display will show unavailable on Windows.
- Test with a non-critical Windows machine first. Keep a recovery route (restart / elevated app) available while validating network protection.

See the upstream Windows platform guide for runtime and recovery details:
https://github.com/XIIIFOX/flutter_vless/blob/main/doc/platform/windows.md
