import SwiftUI
import Iori

@main
struct IoriServerSampleApp: App {
    
    init() {
        AppManager.shared.loadConfiguration()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
