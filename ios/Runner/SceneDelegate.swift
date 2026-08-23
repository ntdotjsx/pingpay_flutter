import Flutter
import UIKit
import LineSDK

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    if let url = URLContexts.first?.url {
      _ = LoginManager.shared.application(UIApplication.shared, open: url)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let url = connectionOptions.urlContexts.first?.url {
      _ = LoginManager.shared.application(UIApplication.shared, open: url)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
