#!/usr/bin/env bash
set -euo pipefail

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to the Developer ID Application certificate name.}"
: "${RELEASE_VERSION:?Set RELEASE_VERSION to the release version without a v prefix.}"

product_name="Flapline"
build_dir="build"
saver_path="${build_dir}/Build/Products/Release/${product_name}.saver"
artifact_dir="dist/release"
staging_dir="dist/staging/${product_name}.saver"
dmg_path="${artifact_dir}/${product_name}-${RELEASE_VERSION}-macOS.dmg"

rm -rf "${artifact_dir}" "dist/staging"
mkdir -p "${artifact_dir}" "dist/staging"

xcodebuild \
  -project SplitFlap.xcodeproj \
  -scheme SplitFlap \
  -configuration Release \
  -derivedDataPath "${build_dir}" \
  ONLY_ACTIVE_ARCH=NO \
  build

[[ -d "${saver_path}" ]] || { echo "Missing ${saver_path}" >&2; exit 1; }
cp -R "${saver_path}" "${staging_dir}"

codesign --force --options runtime --timestamp --sign "${DEVELOPER_ID_APPLICATION}" \
  "${staging_dir}/Contents/MacOS/${product_name}"
codesign --force --options runtime --timestamp --sign "${DEVELOPER_ID_APPLICATION}" "${staging_dir}"
codesign --verify --deep --strict --verbose=2 "${staging_dir}"

hdiutil create -volname "${product_name}" -srcfolder "dist/staging" -ov -format UDZO "${dmg_path}"
echo "${dmg_path}"
