package net.iraobi.scripturedemoplayer

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		// Ensure Flutter receives the newest intent for plugins that observe it
		setIntent(intent)
	}
}
