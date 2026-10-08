package ee.softimply.lavka_update

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/** Starts the host app the way the launcher would, then gets out of the way. */
class LavkaOpenActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(it)
        }
        finish()
    }
}
