import Foundation

class PingMonitor {
    
    let connection: Connection
    let timeout: Int
    let interval: Int
    
    private(set) var isRunning = false
    private let queue = DispatchQueue(label: "IoriPingMonitor")
    private var receivedPong = true
    
    init(connection: Connection, timeout: Int = 60, interval: Int = 5) {
        self.connection = connection
        self.timeout = timeout
        self.interval = interval
        queue.suspend()
    }
    
    func start() {
        Log.iori.debug("start ping monitor => \(connection.connectionId)")
        isRunning = true
        receivedPong = true
        queue.resume()
        queue.async {
            self.loop()
        }
    }
    
    private func loop() {
        guard isRunning else {
            return
        }
        guard receivedPong else {
            connection.errorLog("PongTimeout")
            connection.disconnect(reason: IoriError.pongTimeout)
            return
        }
        
        connection.sendPing()
        queue.asyncAfter(deadline: .now() + Double(interval)) {
            self.loop()
        }
    }
    
    func stop() {
        isRunning = false
        queue.suspend()
    }
    
    func didReceivePong() {
        receivedPong = true
    }
    
}
