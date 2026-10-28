// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html';

void observeLifecycle(void Function() onOnline, void Function() onOffline) {
  window.onPageHide.listen((_) => onOffline());
  window.onBeforeUnload.listen((_) => onOffline());
  window.onFocus.listen((_) => onOnline());
  document.addEventListener('visibilitychange', (event) {
    if (document.visibilityState == 'hidden') {
      onOffline();
    } else if (document.visibilityState == 'visible') {
      onOnline();
    }
  });
}
