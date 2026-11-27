package com.amon.fixer

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Some devices (seen on Samsung) don't re-send window insets when the app
    // returns from another app, so Flutter keeps stale values: a keyboard
    // that is no longer open, and no space for the navigation bar. Asking for
    // the insets again whenever the window regains focus refreshes them.
    override fun onResume() {
        super.onResume()
        window.decorView.requestApplyInsets()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) window.decorView.requestApplyInsets()
    }
}
