/// In-app update check and version display for apps distributed through
/// Lavka (https://lavka.softimply.tech).
///
/// ```dart
/// void main() {
///   LavkaUpdate.configure(appId: 'potik');
///   runApp(MaterialApp(
///     builder: (context, child) => LavkaUpdateGate(child: child!),
///     ...
///   ));
/// }
/// // after sign-in / sign-out:
/// LavkaUpdate.setUser(email);
/// // on a settings or about screen:
/// const LavkaVersionTile()
/// ```
library;

export 'src/client.dart' show LavkaUpdate, LavkaUpdateStatus;
export 'src/widgets.dart' show LavkaUpdateGate, LavkaVersionTile, LavkaVersionText;
