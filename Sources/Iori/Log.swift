import Foundation
import Puppy

enum Log {
    
    private static let ioriLogLabel = "iori.iori"
    private static let ayameLogLabel = "iori.ayame"
    private static let signalingLogLabel = "iori.signaling"
    private static let webhookLogLabel = "iori.webhook"

    private static let ioriLogFile = "iori.log"
    private static let ayameLogFile = "ayame.log"
    private static let signalingLogFile = "signaling.log"
    
    // MARK: - ファイルローテーション
    
    private static let maxFileSize = 10 * 1024 * 1024
    private static let maxArchivedFilesCount = 5
    private static let fileRotationLoggerDelegate: FileRotationLoggerDeletate = MainFileRotationLoggerDeletate()
    
    static let iori: Puppy = {
        let log = Puppy()
        initializeLogger(log, label: ioriLogLabel, logLevel: .info)
        return log
    }()
    
    static let ayame: Puppy = {
        let log = Puppy()
        initializeLogger(log, label: ayameLogLabel, logLevel: .info)
        return log
    }()
    
    static let signaling = Puppy()
    
    static let webhook: Puppy = {
        let log = Puppy()
        initializeLogger(log, label: webhookLogLabel, logLevel: .info)
        return log
    }()
    
    private static var isRunning = false
    
    static func start() {
        guard !isRunning else {
            return
        }
        
        iori.info("start logging")
        isRunning = true
        
        let config = Configuration.shared
        let logLevel: LogLevel = config.debug ? .debug : .info
        let ioriLogLevel: LogLevel = config.ioriDebug ? .debug : .info

        let ioriFileRotation = createFileRotationLogger(label: ioriLogLabel, fileURL: Configuration.shared.ioriLogPath)
        initializeLogger(iori, label: ioriLogLabel, logLevel: ioriLogLevel, fileRotationLogger: ioriFileRotation)
        
        let ayameFileRotation = createFileRotationLogger(label: ayameLogLabel, fileURL: Configuration.shared.ayameLogPath)
        initializeLogger(ayame, label: ayameLogLabel, logLevel: logLevel, fileRotationLogger: ayameFileRotation)

        let signalingFileRotation = createFileRotationLogger(label: signalingLogLabel, fileURL: Configuration.shared.signalingLogPath)
        initializeLogger(signaling, label: signalingLogLabel, logLevel: .debug, fileRotationLogger: signalingFileRotation)

        let webhookFileRotation = createFileRotationLogger(label: webhookLogLabel, fileURL: Configuration.shared.webhookLogPath)
        initializeLogger(webhook, label: webhookLogLabel, logLevel: logLevel, fileRotationLogger: webhookFileRotation)
    }
    
    private static func initializeLogger(_ log: Puppy, label: String, logLevel: LogLevel,
                             fileRotationLogger: FileRotationLogger? = nil) {
        for logger in log.loggers {
            logger.enabled = false
        }
        log.removeAll()

        let consoleLogger = ConsoleLogger("\(label).console")
        consoleLogger.format = LogFormatter()
        log.add(consoleLogger, withLevel: logLevel)
        
        if let fileRotationLogger = fileRotationLogger {
            log.add(fileRotationLogger, withLevel: logLevel)
        }
    }
    
    private static func createFileRotationLogger(label: String, fileURL: URL) -> FileRotationLogger? {
        do {
            iori.info("log file path => \(fileURL.path)")
            let logger = try FileRotationLogger("\(label).filerotation", fileURL: fileURL)
            logger.delegate = fileRotationLoggerDelegate
            logger.format = LogFormatter()
            logger.maxFileSize = FileRotationLogger.ByteCount(maxFileSize)
            logger.maxArchivedFilesCount = UInt8(maxArchivedFilesCount)
            return logger
        } catch let error {
            iori.error("cannot create \(fileURL.path) => \(error)")
            return nil
        }
    }
    
}

private class LogFormatter: LogFormattable {
    func formatMessage(_ level: LogLevel, message: String, tag: String, function: String,
                       file: String, line: UInt, swiftLogInfo: [String : String],
                       label: String, date: Date, threadID: UInt64) -> String {
        let date = dateFormatter(date,
                                 dateFormat: "yyyy-MM-dd HH:mm:ss.SSSZZZZZ", timeZone: "UTC")
        return "\(date) [\(level)] \(message)"
    }
}

private class MainFileRotationLoggerDeletate: NSObject, FileRotationLoggerDeletate {
    
    func fileRotationLogger(_ fileRotationLogger: FileRotationLogger, didArchiveFileURL: URL, toFileURL: URL) {
        Log.iori.info("archived log file \(fileRotationLogger.label) => \(toFileURL.path)")
    }
    
    func fileRotationLogger(_ fileRotationLogger: FileRotationLogger, didRemoveArchivedFileURL fileURL: URL) {
        Log.iori.info("removed archived log file \(fileRotationLogger.label) => \(fileURL.path)")
    }
    
}

extension Puppy {
    
    func error(_ message: String, rawMessage: Message) {
        error("\(message) rawMessage=\(message)")
    }
    
}
