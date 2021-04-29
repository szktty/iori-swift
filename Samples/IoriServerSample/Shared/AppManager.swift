import Foundation
import Yaml
import Iori

class AppManager {
    
    static var shared = AppManager()
    
    var configuration: Configuration?
    
    func loadConfiguration() {
        let fileName = Configuration.defaultFileName
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            fatalError()
        }
        
        guard let configuration = Configuration.load(contentsOf: url) else {
            fatalError()
        }
        self.configuration = configuration
    }
    
}
