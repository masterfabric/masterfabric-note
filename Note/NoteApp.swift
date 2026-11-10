import SwiftUI
import UIKit

@main
struct NoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = NoteStore.shared
    @State private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .modifier(HingeCover())
                .environment(store)
                .environment(settings)
                .preferredColorScheme(settings.appearance.scheme)
                .tint(Color(red: 0.12, green: 0.26, blue: 0.72))
                .onOpenURL { Router.shared.handle(url: $0) }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        PhoneSync.shared.start()
        NoteStore.shared.onSave = {
            PhoneSync.shared.push()
            WidgetBridge.update()
        }
        WidgetBridge.update()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem { Router.shared.handle(shortcut: item.type) }
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        Router.shared.handle(shortcut: shortcutItem.type)
        completionHandler(true)
    }
}
