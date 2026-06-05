import Flutter
import UIKit

@objc(MNFlutterViewController)
class MNFlutterViewController: FlutterViewController {
  @objc(createTouchRateCorrectionVSyncClientIfNeeded)
  func createTouchRateCorrectionVSyncClientIfNeeded() {
    // Work around a Flutter 3.44.0 engine crash on ProMotion iPhones running iOS 26.5.
    // The normal rendering vsync client remains active; this disables only touch-rate correction.
  }
}
