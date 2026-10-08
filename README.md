# lavka_update

In-app update check and version display for SoftImply's Android apps,
distributed through [Lavka](https://lavka.softimply.tech), our internal app store.

- **Update banner.** On start and on every return to the foreground (at most
  hourly), the app asks Lavka whether a newer build exists. If so, a banner
  slides in at the bottom: *Update* opens the app's Lavka page in the browser
  (Microsoft sign-in, then Install), *Later* hides it until the next build.
- **Version display.** `LavkaVersionTile` for a settings screen,
  `LavkaVersionText` for a footer: `1.0.0 (45)` plus "update available".
- **Who runs what.** Each check reports this build's version, the signed-in
  user's email (if the app sets it) and a random install id, so Lavka's app
  page lists who is behind.

## Use

```yaml
dependencies:
  lavka_update:
    git:
      url: https://github.com/SoftImply-OU/lavka_update.git
      ref: v0.1.0
```

```dart
import 'package:lavka_update/lavka_update.dart';

void main() {
  LavkaUpdate.configure(appId: 'potik'); // the app's id in Lavka
  runApp(MaterialApp(
    builder: (context, child) => LavkaUpdateGate(child: child!),
    home: ...,
  ));
}

// after sign-in, and with null after sign-out
LavkaUpdate.setUser(user.email);

// settings / about screen
const LavkaVersionTile()
```

The check only runs on Android, the only platform Lavka distributes. The
version widgets work everywhere.

## What it sends

`POST https://lavka.softimply.tech/api/updates/<appId>` with
`{versionCode, versionName, email?, device}`. `device` is a random id made
on first run and kept in shared preferences; it is not a hardware id. The
endpoint is the one path of Lavka that is reachable without Cloudflare
Access, and it answers with version numbers only.

This repo is public on purpose: the apps' CI fetches it without credentials.
Keep secrets and internal URLs other than Lavka's out of it.
