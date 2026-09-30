import SwiftUI

@main
struct FramewiseApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            CameraScreen(settings: settings)
                .preferredColorScheme(.dark)
        }
    }
}
