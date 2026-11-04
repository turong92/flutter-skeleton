import Flutter
import NidThirdPartyLogin
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // The app uses scenes, so the Naver app's answer arrives here, not in
  // AppDelegate.application(_:open:options:).
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      if NidOAuth.shared.handleURL(context.url) {
        return
      }
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
