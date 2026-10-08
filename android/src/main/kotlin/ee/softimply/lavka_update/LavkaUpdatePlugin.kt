package ee.softimply.lavka_update

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Exists so Flutter links this package's Android library (and with it
 * LavkaOpenActivity) into the app. There is no method channel: everything
 * else in lavka_update is plain Dart.
 */
class LavkaUpdatePlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {}

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
