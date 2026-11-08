# Android and web releases

Use Godot **4.6.2 Standard**, its matching export templates, OpenJDK 17, and Android
SDK platform 35 / build-tools 35.0.1. Run `tools/configure_android.py --java PATH
--sdk PATH` to configure Godot's SDK paths.

## Android APK

The Android preset builds an ARM64 APK for Android 7.0 or later, in landscape.
It uses package ID `com.kurtreonal.unnamedfantasy`, version `0.1.0`, version code 1.
Movement, attack, interaction, weapon/element/skill switching, and recall have
touch controls. Bow/staff aiming uses the last movement direction on touch devices.

Export a signed APK with `godot --headless --path . --export-release Android`.
Supply signing credentials through these environment variables, not the preset:

- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`

A dedicated key was generated locally under `.private/android-signing/`.
That folder is ignored by both Git and Godot. Back up the keystore **and** its
credentials privately before deleting or moving this checkout. The same key is
needed to update installed copies of the app. Signing keys are free to generate.
Never upload the folder as a repository file or a public release asset.

For automated signed releases, add these repository **Actions secrets**:

- `ANDROID_KEYSTORE_BASE64`: base64 encoding of the private `.p12` keystore.
- `ANDROID_KEY_ALIAS`: the alias from the private credentials file.
- `ANDROID_KEY_PASSWORD`: its password.

The release workflow does not receive the signing key until those secrets are
configured. Increase Android `version/code`, update both version names, then run
**Build signed Android release** manually with the matching `v...` tag.
This is a sideloadable GitHub APK release; publishing on Google Play also requires
its separate developer-account and store-submission process.

## Playable web version

Export with `godot --headless --path . --export-release Web`.
Serve `build/web/` through HTTP/HTTPS; opening `index.html` as a local file does
not work. The single-threaded Compatibility/WebGL 2 export works on static hosting
without cross-origin-isolation headers. A modern browser with WebAssembly and
WebGL 2 support is required. Use landscape on phones; keyboard/mouse controls
remain available on desktop. Browser audio can require a click/tap first.

Enable **Settings → Pages → Source: GitHub Actions** once. The web workflow
publishes the playable build after each push to `main`.

Build outputs and private keys are excluded from source control. Publish APKs,
web ZIPs, and checksums as GitHub release assets rather than committing binaries.
