// Web and native lifecycle hooks are kept separate so room presence stays
// available to all Flutter targets without relying on a web-only SDK.
import 'room_presence_stub.dart'
    if (dart.library.html) 'room_presence_web.dart';

void observeRoomPageLifecycle(void Function() onOnline, void Function() onOffline) =>
    observeLifecycle(onOnline, onOffline);
