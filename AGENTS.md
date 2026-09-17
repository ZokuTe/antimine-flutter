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

Date-based: `year.month.day` of the release. A second build on the same day
appends a hotfix revision, e.g. `26.9.17+hotfix.1`.

The `pubspec.yaml` version is `name+build`:

```yaml
version: 26.9.17+6      # versionName=26.9.17, versionCode=6
```

**`versionCode` must strictly increase** or Android refuses to install the new
APK over an existing one. Bump the number after `+` on every release.

## Release process

### 1. Bump the version

Edit `pubspec.yaml`. Both the date and the build number change:

```yaml
version: 26.9.17+6   ->   version: 26.9.18+7
```

Check nothing else hardcodes the version:

```sh
grep -rn "26\.9\.17" --include=*.yaml --include=*.dart --include=*.gradle \
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

### 3. Build

```sh
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

### 4. Verify the artifact

```sh
export PATH="/home/zokute/Android/Sdk/build-tools/36.0.0:$PATH"
APK=build/app/outputs/flutter-apk/app-release.apk

aapt dump badging "$APK" | grep '^package:'   # versionCode / versionName
apksigner verify --print-certs "$APK"         # must not be a debug key
zipalign -c -P 16 -v 4 "$APK"                 # must print "Verification successful"
sha256sum "$APK"
```

Expect `targetSdkVersion:'36'`, `minSdkVersion 24`, and ABIs
`arm64-v8a armeabi-v7a x86_64`.

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
git commit -m "chore: release 26.9.18"

git push origin main
git tag -a v26.9.18 -m "Antimine 26.9.18"
git push origin v26.9.18
```

### 6. Create the release

```sh
gh release create v26.9.18 \
  build/app/outputs/flutter-apk/app-release.apk \
  --repo ZokuTe/antimine-flutter \
  --title "Antimine 26.9.18 — Android 16 build" \
  --notes-file /tmp/release-notes.md \
  --latest
```

The notes should include the install instructions, the SHA-256 of the APK, the
requirements, and what changed. Use `--latest` so it becomes the recommended
download.

### 7. Confirm the upload

Download the asset again and compare hashes. **Do this as a single sequential
command** — two concurrent downloads writing the same file will interleave and
produce a bogus mismatch.

```sh
gh release download v26.9.18 --repo ZokuTe/antimine-flutter \
  --pattern "app-release.apk" --output /tmp/verify.apk --clobber
sha256sum /tmp/verify.apk
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
