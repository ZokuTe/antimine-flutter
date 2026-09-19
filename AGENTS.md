# AGENTS.md

Guidance for agents working in this repository.

This is a fork of [lucasnlm/antimine-flutter](https://github.com/lucasnlm/antimine-flutter).
The fork exists to ship an Android 16 build plus appearance features; see
`git log` for the changes carried on top of upstream.

## Remotes

```
origin    git@github.com:ZokuTe/antimine-flutter.git     # this fork
upstream  https://github.com/lucasnlm/antimine-flutter.git
```

Push to `origin`. Never push to `upstream`.

`gh` defaults to the upstream repository, so **every `gh` command must pass
`--repo ZokuTe/antimine-flutter`**. Without it, commands such as
`gh release create` fail with "tag exists locally but has not been pushed to
lucasnlm/antimine-flutter".

## Environment

Not in the repo; the paths below are what the local machine uses.

| Tool | Path |
| --- | --- |
| Flutter 3.47.4 | `/home/zokute/fvm/versions/stable/bin` |
| Android SDK | `/home/zokute/Android/Sdk` |
| build-tools | `/home/zokute/Android/Sdk/build-tools/36.0.0` |
| platform-tools | `/home/zokute/Android/Sdk/platform-tools` |

`ANDROID_HOME` is not always exported in a fresh shell. Set it before building:

```sh
export ANDROID_HOME=/home/zokute/Android/Sdk
export PATH="/home/zokute/fvm/versions/stable/bin:$PATH"
```

`android/local.properties` and `android/key.properties` are gitignored and must
exist locally. Release signing uses `android/app/antimine-release.p12`.

## Commits

GPG signing is enabled (`commit.gpgsign=true`). The key needs a passphrase, and
`git commit` will block on a pinentry prompt. If a commit fails with
`gpg: signing failed: 超时`, ask the user to unlock the agent, then retry —
do not fall back to `--no-gpg-sign` unless asked.

## Versioning

Date-based: `year.month.day`, followed by a revision letter. The first build
on a given day is always `a`; each further build that day takes the next
letter in order.

```
26.9.18-a   first build on 2026-09-18
26.9.18-b   second build the same day
26.9.18-c   third
```

The letter is separated by a hyphen because Pub parses this field as semver
and rejects a letter appended directly to the version core
(`26.9.18b` fails with "Invalid version number"). Flutter passes everything
before the `+` through as `versionName`, so the APK reports `26.9.18-b`, and
the tag and GitHub release carry it too (`v26.9.18-b`).

The `pubspec.yaml` version is `name+build`:

```yaml
version: 26.9.18-a+7      # versionName=26.9.18-a, versionCode=7
```

**`versionCode` must strictly increase** or Android refuses to install the new
APK over an existing one. Bump the number after `+` on every release,
independently of the letter.

## Release process

### Asset naming and CPU architectures

Every release asset must state the platform and the CPU architecture it
runs on. Name assets `antimine-<version>-<platform>-<arch>.<ext>` and list
the same architectures in the release notes:

| Platform | Asset | Architectures shipped |
| --- | --- | --- |
| Android | `antimine-<version>-android-<arch>.apk` | `arm64`, `x86_64` |
| Windows | `antimine-<version>-windows-<arch>.zip` | `x86_64` |

Architecture strings follow what the platform itself reports:

- Android: derive them from `aapt dump badging` `native-code:`: `arm64-v8a`
  -> `arm64`, `x86_64` -> `x86_64`. If a 32-bit build is ever shipped,
  `armeabi-v7a` -> `armeabi-v7a`.
- Windows: the only buildable target is `x86_64`.

The release notes must include a table mapping each asset to the devices it
covers (Android `arm64` = virtually all phones, Android `x86_64` =
emulators, Windows `x86_64` = regular PCs).

### 1. Bump the version

Edit `pubspec.yaml`. The revision letter and the build number both change;
the date changes only on the day's first release:

```yaml
version: 26.9.18-a+7   ->   version: 26.9.18-b+8
```

Check nothing else hardcodes the version:

```sh
grep -rn "26\.9\.18" --include=*.yaml --include=*.dart --include=*.gradle \
  --include=*.json . | grep -v '^./build/'
```

Only `pubspec.yaml` should match (`.dart_tool/package_graph.json` is generated).

### 2. Verify before building

CI (`.github/workflows/flutter.yml`) runs these on every push, so run them
locally first:

```sh
# Format check, excluding generated files
find lib test -name '*.dart' ! -name '*.g.dart' -print0 \
  | xargs -0 dart format --output=none --set-exit-if-changed

flutter analyze .
flutter test
```

Generated `*.g.dart` files are excluded from the format check on purpose:
slang writes `lib/foundation/i18n/translations*.g.dart` with its own
formatting, so `dart format` would rewrite them and the next
`dart run slang` would undo it. To fix formatting, format only handwritten
sources:

```sh
find lib test -name '*.dart' ! -name '*.g.dart' -print0 | xargs -0 dart format
```

`flutter analyze` reports 3 pre-existing issues (`unawaited_return_in_try_block`
in `native_minefield_creator.dart`, two deprecated `Radio` members in
`language_screen.dart`). These are expected; do not "fix" them as part of an
unrelated change.

### 3. Build the APKs

```sh
flutter build apk --release --split-per-abi
```

`--split-per-abi` produces one APK per CPU architecture in
`build/app/outputs/flutter-apk/`:

- `app-arm64-v8a-release.apk`
- `app-armeabi-v7a-release.apk`
- `app-x86_64-release.apk`

Copy the architectures being released into their asset names (see "Asset
naming and CPU architectures" above):

```sh
mkdir -p "/tmp/release-26.9.19-a"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  /tmp/release-26.9.19-a/antimine-26.9.19-a-android-arm64.apk
cp build/app/outputs/flutter-apk/app-x86_64-release.apk \
  /tmp/release-26.9.19-a/antimine-26.9.19-a-android-x86_64.apk
```

`armeabi-v7a` is built but not released unless needed.

### 4. Verify the APKs

```sh
export PATH="/home/zokute/Android/Sdk/build-tools/36.0.0:$PATH"

for APK in /tmp/release-26.9.19-a/*.apk; do
  echo "== $APK =="
  aapt dump badging "$APK" | grep '^package:'     # versionCode / versionName
  aapt dump badging "$APK" | grep 'native-code:'  # exactly one ABI
  apksigner verify --print-certs "$APK"           # must not be a debug key
  zipalign -c -P 16 -v 4 "$APK"                   # "Verification successful"
  sha256sum "$APK"
done
```

Expect `targetSdkVersion:'36'` and `minSdkVersion 24`. Each APK's
`native-code:` line must contain exactly one ABI and match the architecture
in its file name (`'arm64-v8a'` for `-arm64`, `'x86_64'` for `-x86_64`).

`apksigner` must report the release certificate:

```
CN=Antimine, OU=Mobile, O=Antimine, L=Unknown, ST=Unknown, C=US
SHA-256: d2ac7676...585a1a
```

If it reports a debug certificate, `android/key.properties` is missing or
malformed.

### 5. Commit, tag, push

```sh
git add pubspec.yaml
git commit -m "chore: release 26.9.18-b"

git push origin main
git tag -a v26.9.18-b -m "Antimine 26.9.18-b"
git push origin v26.9.18-b
```

### 6. Build the Windows package

Flutter refuses to build Windows binaries on non-Windows hosts, so the
Windows package comes from the manual CI workflow
(`.github/workflows/windows.yml`). Trigger it after step 5, once the release
commit is on `origin/main`, so the built version matches the tag:

```sh
gh workflow run windows.yml --repo ZokuTe/antimine-flutter
run_id=$(gh run list --workflow=windows.yml --limit 1 --json databaseId \
  -q '.[0].databaseId' --repo ZokuTe/antimine-flutter)
gh run watch "$run_id" --repo ZokuTe/antimine-flutter
gh run download "$run_id" --name antimine-windows-x86_64 --dir /tmp/win \
  --repo ZokuTe/antimine-flutter
```

The workflow builds `flutter build windows --release`, zips
`build/windows/x64/runner/Release`, prints the SHA-256 of the zip in the
`Package` step of the build log, and uploads the zip as an artifact
(retained 30 days). Rename it into the release name and verify the hash
against the build log:

```sh
cp /tmp/win/antimine-windows-x86_64.zip \
  /tmp/release-26.9.19-a/antimine-26.9.19-a-windows-x86_64.zip
sha256sum /tmp/release-26.9.19-a/antimine-26.9.19-a-windows-x86_64.zip
```

### 7. Create the release

```sh
gh release create v26.9.19-a \
  /tmp/release-26.9.19-a/antimine-26.9.19-a-android-arm64.apk \
  /tmp/release-26.9.19-a/antimine-26.9.19-a-android-x86_64.apk \
  /tmp/release-26.9.19-a/antimine-26.9.19-a-windows-x86_64.zip \
  --repo ZokuTe/antimine-flutter \
  --title "Antimine 26.9.19-a — Android 16 (arm64, x86_64) + Windows x86_64" \
  --notes-file /tmp/release-notes.md \
  --latest
```

The notes must include the install instructions, the SHA-256 of every
asset, the requirements, the CPU-architecture table (see "Asset naming and
CPU architectures"), and what changed. Use `--latest` so it becomes the
recommended download.

### 8. Confirm the upload

Download every asset again and compare hashes. **Run the downloads
sequentially** — concurrent downloads writing the same file will interleave
and produce a bogus mismatch.

```sh
for ASSET in antimine-26.9.19-a-android-arm64.apk \
             antimine-26.9.19-a-android-x86_64.apk \
             antimine-26.9.19-a-windows-x86_64.zip; do
  gh release download v26.9.19-a --repo ZokuTe/antimine-flutter \
    --pattern "$ASSET" --output "/tmp/verify-$ASSET" --clobber
  sha256sum "/tmp/verify-$ASSET"
done
```

## Notes on the code

- `android/key.properties`, `android/app/antimine-release.p12` and
  `android/local.properties` are gitignored. Confirm with `git status
  --porcelain` before pushing that none of them are staged.
- Native code lives in `packages/creator`. It is built by CMake for Android and
  by `cmake -S packages/creator/src -B <dir>` for desktop, so a change there can
  be exercised locally without a device.
- The localizations are generated from `external/l10n/i18n` by
  `dart run slang`. Missing keys fall back to the base locale, so a new string
  only needs to be added to `strings.i18n.json` (and any language being
  translated).
- `windows-latest` ships Visual Studio 2026, whose MSVC rejects the
  `<experimental/coroutine>` header used by `audioplayers_windows` < 4.4.1
  (error C2338). Keep `audioplayers_windows` at 4.4.1+ (currently pulled in
  via `audioplayers` 6.8.1) or the Windows CI build breaks.
