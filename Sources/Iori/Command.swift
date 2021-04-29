import Foundation
import ArgumentParser

/** :nodoc: */
public class Command {
    
    public let workingDirectory: String
    public let options: Options
    
    public var configurationURL: URL {
        URL(fileURLWithPath: options.configurationFile,
            relativeTo: URL(fileURLWithPath: workingDirectory))
    }
    
    public init(workingDirectory: String, options: Options) {
        self.workingDirectory = workingDirectory
        self.options = options
    }
    
    public func run() {
        guard let configuration = loadConfiguration() else {
            print("no such configuration file: \(options.configurationFile)")
            Command.Runner.exit(withError: IoriError.configurationFailed)
        }
        configuration.baseDirectory = URL(fileURLWithPath: workingDirectory)

        AyameServer.shared.start(configuration: configuration) { error in
            guard error == nil else {
                Command.Runner.exit(withError: IoriError.serverStartFailed)
            }
        }
        CFRunLoopRun()
    }
    
    private func loadConfiguration() -> Configuration? {
        guard FileManager.default.fileExists(atPath: configurationURL.path) else {
            print("no such configuration file: \(configurationURL.path)")
            Command.Runner.exit(withError: IoriError.configurationFailed)
        }
        return Configuration.load(contentsOf: configurationURL)
    }
    
    public struct Options {
        public var configurationFile = Configuration.defaultFileName
    }
    
    public struct Runner: ParsableCommand {
        
        public static let _commandName = "iori"
        
        @Option(name: .short, help: ArgumentHelp("設定ファイルのパス (ayame.yaml)", valueName: "string"))
        var configurationFile: String?
        
        public init() {}
        
        mutating public func run() throws {
            var options = Command.Options()
            
            if let file = configurationFile {
                options.configurationFile = file
            }
            
            let command = Command(workingDirectory: FileManager.default.currentDirectoryPath, options: options)
            command.run()
        }
        
    }
    
}

