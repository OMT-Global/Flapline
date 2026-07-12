# Flapline Public Launch

This is the public-facing launch checklist for Flapline.

## Name And Domain

- Product name: **Flapline**
- Canonical domain: **flapline.app**
- macOS bundle identifier: **app.flapline.screensaver**
- Public tagline: **A split-flap screensaver with somewhere to be.**
- Short description: **A quiet split-flap screensaver for macOS with custom messages, clocks, dates, Unicode, and themes.**

Use only `flapline.app` for the public site. Do not launch a parallel `www`
site.

## Domain Registration

Register only:

```text
flapline.app
```

Suggested DNS for GitHub Pages apex hosting:

```text
A     @    185.199.108.153
A     @    185.199.109.153
A     @    185.199.110.153
A     @    185.199.111.153
AAAA  @    2606:50c0:8000::153
AAAA  @    2606:50c0:8001::153
AAAA  @    2606:50c0:8002::153
AAAA  @    2606:50c0:8003::153
```

Keep the domain locked after registration. Enable auto-renew if the registrar
account has a safe payment method.

## Website

The static site lives in:

```text
website/
```

The GitHub Pages workflow publishes that folder to:

```text
https://flapline.app
```

The `website/CNAME` file is the source of truth for the custom domain.

## Apple Signing Answer

Yes. Public downloads should be signed with a Developer ID certificate and
notarized before release.

Unsigned local builds are fine for development and personal testing, but a
public `.saver` download should avoid Gatekeeper friction. Apple documents that
Gatekeeper checks Developer ID certificates for software distributed outside the
Mac App Store, and Apple recommends notarization for additional trust on modern
macOS.

For this project, plan on:

1. Build a Release `.saver`.
2. Sign with Developer ID Application.
3. Package as a `.zip`, `.dmg`, or `.pkg`.
4. Submit to Apple notary service with `xcrun notarytool`.
5. Staple the ticket when the package format supports it.
6. Attach the notarized artifact to the GitHub Release.

## GitHub release signing and notarization

The `macOS Notarized Release` workflow runs on an exact `vX.Y.Z` tag or by
manual dispatch. It uses the protected `prod` GitHub environment and requires
these environment secrets:

- `MACOS_DEVELOPER_ID_P12_BASE64`: base64-encoded Developer ID Application P12.
- `MACOS_DEVELOPER_ID_P12_PASSWORD`: password for that P12.
- `MACOS_KEYCHAIN_PASSWORD`: an arbitrary, per-run keychain password.
- `MACOS_DEVELOPER_ID_APPLICATION`: exact Developer ID Application certificate name.
- `APPLE_NOTARY_KEY_BASE64`: base64-encoded App Store Connect API-key P8.
- `APPLE_NOTARY_KEY_ID`: App Store Connect API key ID.
- `APPLE_NOTARY_ISSUER_ID`: App Store Connect issuer ID.

The workflow imports the certificate into a temporary keychain, signs the
bundle with hardened runtime and a secure timestamp, creates a DMG, notarizes
it with `notarytool`, staples the resulting ticket, and uploads the DMG plus a
SHA-256 checksum to the matching GitHub Release. No Apple credential belongs in
the repository or in unprotected repository-level secrets.

## Release Checklist

Before `v1.0.0`:

- [ ] Confirm `flapline.app` is registered and DNS is configured.
- [ ] Confirm GitHub Pages serves `https://flapline.app`.
- [ ] Confirm `make build` produces `Flapline.saver`.
- [ ] Confirm `make install` installs `~/Library/Screen Savers/Flapline.saver`.
- [ ] Confirm the settings sheet opens and saves options.
- [ ] Confirm idle CPU behavior after ScreenSaverEngine stops.
- [ ] Sign with Developer ID.
- [ ] Notarize the release artifact.
- [ ] Create a GitHub Release with the signed/notarized artifact.
- [ ] Update `website/index.html` download links if the release artifact path changes.

## Suggested First Release Copy

Title:

```text
Flapline 1.0.0
```

Release summary:

```text
Flapline is a macOS screensaver inspired by classic split-flap departure boards.
It supports custom messages, clock and date modes, Unicode text, themes,
configurable wave timing, and idle-friendly Core Animation rendering.
```

Install note:

```text
Download the signed release, open it, and install Flapline.saver into
~/Library/Screen Savers. Then choose Flapline from System Settings -> Screen Saver.
```
