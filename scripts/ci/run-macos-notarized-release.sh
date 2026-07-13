#!/usr/bin/env bash
set -euo pipefail

: "${RELEASE_VERSION:?Set RELEASE_VERSION to the release version without a v prefix.}"

required_env=(
  APPLE_DEVELOPER_CERT_P12
  APPLE_CERT_PASSWORD
  APPLE_NOTARY_KEY_ID
  APPLE_NOTARY_KEY_ISSUER
  APPLE_NOTARY_PRIVATE_KEY
)
missing=()
for name in "${required_env[@]}"; do
  [[ -n "${!name:-}" ]] || missing+=("${name}")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Apple notarization credentials are incomplete; missing: ${missing[*]}" >&2
  exit 1
fi

if [[ "${FLAPLINE_NOTARIZE_DRY_RUN:-0}" == "1" ]]; then
  echo "Flapline notarization inputs are present; dry run requested."
  exit 0
fi

for tool in codesign hdiutil security shasum xcodebuild xcrun; do
  command -v "${tool}" >/dev/null 2>&1 || { echo "Required tool not found: ${tool}" >&2; exit 1; }
done

decode_base64() {
  local value="$1" output="$2"
  printf '%s' "$value" | base64 --decode >"$output" 2>/dev/null || printf '%s' "$value" | base64 -D >"$output"
}

product_name="Flapline"
build_dir="build"
saver_path="${build_dir}/Build/Products/Release/${product_name}.saver"
artifact_dir="dist/release"
staging_dir="dist/staging/${product_name}.saver"
dmg_path="${artifact_dir}/${product_name}-${RELEASE_VERSION}-macOS.dmg"
tmp_dir="$(mktemp -d)"
keychain="${tmp_dir}/flapline-notarization.keychain-db"
certificate_path="${tmp_dir}/developer-id.p12"
notary_key_path="${tmp_dir}/notary-key.p8"
keychain_password="$(uuidgen | tr -d '-')"
signing_identity="${APPLE_DEVELOPER_IDENTITY:-Developer ID Application}"

existing_keychains=()
while IFS= read -r keychain_path; do
  existing_keychains+=("${keychain_path//\"/}")
done < <(security list-keychains -d user)
cleanup() {
  security list-keychains -d user -s "${existing_keychains[@]}" >/dev/null 2>&1 || true
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

rm -rf "$artifact_dir" "dist/staging"
mkdir -p "$artifact_dir" "dist/staging"

decode_base64 "$APPLE_DEVELOPER_CERT_P12" "$certificate_path"
decode_base64 "$APPLE_NOTARY_PRIVATE_KEY" "$notary_key_path"
chmod 0600 "$certificate_path" "$notary_key_path"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$certificate_path" -k "$keychain" -P "$APPLE_CERT_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain"
security list-keychains -d user -s "$keychain" "${existing_keychains[@]}"

xcodebuild -project SplitFlap.xcodeproj -scheme SplitFlap -configuration Release -derivedDataPath "$build_dir" ONLY_ACTIVE_ARCH=NO build
[[ -d "$saver_path" ]] || { echo "Missing $saver_path" >&2; exit 1; }
cp -R "$saver_path" "$staging_dir"
codesign --force --options runtime --timestamp --sign "$signing_identity" "$staging_dir/Contents/MacOS/$product_name"
codesign --force --options runtime --timestamp --sign "$signing_identity" "$staging_dir"
codesign --verify --deep --strict --verbose=2 "$staging_dir"

hdiutil create -volname "$product_name" -srcfolder dist/staging -ov -format UDZO "$dmg_path"
xcrun notarytool submit "$dmg_path" --key "$notary_key_path" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_KEY_ISSUER" --wait
xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
shasum -a 256 "$dmg_path" >"${dmg_path}.sha256"
echo "$dmg_path"
