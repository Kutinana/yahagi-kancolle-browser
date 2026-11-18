# webview_flutter_wkwebview

This is the runtime source from Flutter's [webview_flutter_wkwebview 3.27.2](https://pub.dev/packages/webview_flutter_wkwebview/versions/3.27.2), with the upstream BSD license.

`WebViewImpl.observeValue` ignores late KVO notifications after the plugin registrar shuts down. WKWebView can still deliver loading progress notifications after scene or engine teardown. Runner build 36 crashed because the notification read the released registrar through Pigeon's unowned reference.

Use the hosted dependency again when it includes an equivalent guard.
