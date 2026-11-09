@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'youtube_iframe_bridge_web_test_stub.dart'
    if (dart.library.html) 'youtube_iframe_bridge_web_test_impl.dart' as tests;

void main() => tests.main();
