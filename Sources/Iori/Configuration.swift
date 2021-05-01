import Foundation
import Yaml
import Puppy

public class Configuration {
    
    public static var shared = Configuration()
    
    public var debug = false
    public var logDirectory = "."
    public var logName = "ayame.log"
    public var logLevel: LogLevel? = nil
    public var signalingLogName = "signaling.log"
    public var listenIPv4Address = "0.0.0.0"
    public var listenPortNumber = 3000
    public var authnWebHookURL: URL?
    public var disconnectWebHookURL: URL?
    public var webhookLogName = "webhook.log"
    public var webhookRequestTimeout = 5
    public var ioriDebug = false
    public var ioriSignalingDebug = false
    public var ioriLogName = "iori.log"

    public var baseDirectory: URL
    
    public var ioriLogPath: URL {
        baseDirectory.appendingPathComponent(ioriLogName)
    }
    
    public var ayameLogPath: URL {
        baseDirectory.appendingPathComponent(logName)
    }
    
    public var signalingLogPath: URL {
        baseDirectory.appendingPathComponent(signalingLogName)
    }
    
    public var webhookLogPath: URL {
        baseDirectory.appendingPathComponent(webhookLogName)
    }
    
    init() {
        baseDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    public static let defaultFileName = "ayame.yaml"
    
    public static func load() -> Configuration? {
        load(contentsOf: URL(fileURLWithPath: defaultFileName))
    }
    
    public static func load(contentsOf url: URL) -> Configuration? {
        do {
            let data = try Data(contentsOf: url)
            guard let string = String(data: data, encoding: .utf8) else {
                Log.iori.debug("encoding is not UTF-8")
                return nil
            }
            return parse(try Yaml.load(string))
        } catch let error {
            Log.iori.debug("cannot load \(url.path) => \(error)")
            return nil
        }
    }
    
    private static func parse(_ yaml: Yaml) -> Configuration {
        let config = Configuration()

        loadBool(yaml, for: "debug") {
            config.debug = $0
        }
        
        loadString(yaml, for: "log_dir") {
            config.logDirectory = $0
        }
        
        loadString(yaml, for: "log_name") {
            config.logName = $0
        }
        
        loadString(yaml, for: "log_level") {
            switch $0 {
            case "none":
                config.logLevel = nil
            case "debug":
                config.logLevel = .debug
            default:
                config.logLevel = .info
            }
        }
        
        loadString(yaml, for: "signaling_log_name") {
            config.signalingLogName = $0
        }
        
        loadString(yaml, for: "listen_ipv4_address") {
            config.listenIPv4Address = $0
        }
        
        loadInt(yaml, for: "listen_port_number") {
             config.listenPortNumber = $0
         }
        
        loadURL(yaml, for: "authn_webhook_url") {
            config.authnWebHookURL = $0
        }
        
        loadURL(yaml, for: "disconnect_webhook_url") {
            config.disconnectWebHookURL = $0
        }
        
       loadInt(yaml, for: "webhook_request_timeout") {
            config.webhookRequestTimeout = $0
        }
        
        loadString(yaml, for: "webhook_log_name") {
            config.webhookLogName = $0
        }
        
        loadBool(yaml, for: "iori_debug") {
            config.ioriDebug = $0
        }
        
        loadBool(yaml, for: "iori_signaling_debug") {
            config.ioriSignalingDebug = $0
        }
        
        loadString(yaml, for: "iori_log_name") {
            config.ioriLogName = $0
        }
        
        return config
    }
    
    private static func loadBool(_ yaml: Yaml, for name: String, block: (Bool) -> Void) {
        if let value = yaml[.string(name)].bool {
            block(value)
        } else {
            Log.iori.error("\(name) must be bool")
        }
    }
    
    private static func loadString(_ yaml: Yaml, for name: String, block: (String) -> Void) {
        if let value = yaml[.string(name)].string {
            block(value)
        } else {
            Log.iori.error("\(name) must be string")
        }
    }
    
    private static func loadInt(_ yaml: Yaml, for name: String, block: (Int) -> Void) {
        if let value = yaml[.string(name)].int {
            block(value)
        } else {
            Log.iori.error("\(name) must be integer")
        }
    }
    
    private static func loadURL(_ yaml: Yaml, for name: String, block: (URL) -> Void) {
        if let value = yaml[.string(name)].string {
            if let url = URL(string: value) {
                block(url)
            } else {
                Log.iori.error("\(name) must be URL")
            }
        }
    }
    
    public func debugLog() {
        Log.ayame.info("AyameConf debug=\(debug)")
        Log.ayame.info("AyameConf log_dir=\(logDirectory)")
        Log.ayame.info("AyameConf log_name=\(logName)")
        Log.ayame.info("AyameConf log_level=\(logLevel?.description.lowercased() ?? "")")
        Log.ayame.info("AyameConf signaling_log_name=\(signalingLogName)")
        Log.ayame.info("AyameConf listen_ipv4_address=\(listenIPv4Address)")
        Log.ayame.info("AyameConf listen_port_number=\(listenPortNumber)")
        Log.ayame.info("AyameConf authn_webhook_url=\(authnWebHookURL?.path ?? "")")
        Log.ayame.info("AyameConf disconnect_webhook_url=\(disconnectWebHookURL?.path ?? "")")
        Log.ayame.info("AyameConf webhook_log_name=\(webhookLogName)")
        Log.ayame.info("AyameConf webhook_request_timeout_sec=\(webhookRequestTimeout)")
        Log.ayame.info("AyameConf iori_debug=\(ioriDebug)")
        Log.ayame.info("AyameConf iori_signaling_debug=\(ioriSignalingDebug)")
    }
    
}
