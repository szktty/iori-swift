import SwiftUI
import Iori

struct ContentView: View {
    
    var body: some View {
        VStack {
            HStack {
                Button("Start") {
                    if !AyameServer.shared.isRunning {
                        AyameServer.shared.start(configuration:  AppManager.shared.configuration)
                    }
                }
                Button("Stop") {
                    if AyameServer.shared.isRunning {
                        AyameServer.shared.stop()
                    }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
