import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({Key? key}) : super(key: key);

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isError = false;
  bool _isServerError = false; // Detects 500 errors
  double _progress = 0.0;
  String _currentUrl = "https://getrestt.com/";

  String get mobileUserAgent {
    return Platform.isIOS
        ? "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/537.36 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/537.36"
        : "Mozilla/5.0 (Linux; Android 10; Mobile; rv:89.0) Gecko/89.0 Firefox/89.0";
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(mobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _progress = 0.1;
              _isServerError = false;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
              _progress = 1.0;
            });

            // Inject JavaScript to check for 500 errors
            String pageContent = await _controller.runJavaScriptReturningResult("""
                document.body.innerText;
              """) as String;
            pageContent = pageContent.replaceAll('"', '').trim();

            if (pageContent.contains("500 Internal Server Error") ||
                pageContent.contains("Server Error in '/' Application.")) {
              setState(() {
                _isServerError = true;
              });
            }
          },
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (error.errorCode == -2 || error.errorCode == -105) {
              setState(() {
                _isError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: _isLoading
              ? LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                )
              : const SizedBox(height: 4.0),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (!_isError && !_isServerError)
                WebViewWidget(controller: _controller),

              // Loading Indicator on First Load
              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.orange.withOpacity(0.5)),
                  ),
                ),

              // Internet Error Screen
              if (_isError)
                _buildErrorScreen("Please check your internet!", _reloadPage),

              // 500 Internal Server Error Screen
              if (_isServerError)
                _buildErrorScreen("Server Error. Try again now!",
                    _reloadCurrentUrl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String message, VoidCallback onRetry) {
    return Positioned.fill(
      child: Container(
        color: Colors.blueGrey.shade900,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.white, size: 80),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text("Try Again", style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueGrey.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// **Reloads only the last visited URL instead of reloading the whole WebView**
  void _reloadCurrentUrl() {
    setState(() {
      _isError = false;
      _isServerError = false;
      _isLoading = true;
    });
    _controller.loadRequest(Uri.parse(_currentUrl));
  }

  void _reloadPage() {
    setState(() {
      _isError = false;
      _isServerError = false;
      _isLoading = true;
    });
    _controller.reload();
  }
}
