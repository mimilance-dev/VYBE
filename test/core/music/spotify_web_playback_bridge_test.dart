@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'spotify_web_playback_bridge_test_stub.dart'
    if (dart.library.html) 'spotify_web_playback_bridge_test_impl.dart'
    as tests;

void main() => tests.main();
