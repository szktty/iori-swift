import Foundation
import Swifter
import Yaml

public class AyameServer {
    
    enum State {
        case ready
        case running
        case stopped
    }
    
    public static let version = "2021.1"
    
    public static let shared = AyameServer()
    
    static var bundle: Bundle {
        Bundle(for: AyameServer.self)
    }
    
    private(set) var state: State = .ready
    
    public var isRunning: Bool {
        state == .running
    }
    
    public var host: String {
        configuration.listenIPv4Address
    }
    
    public var port: Int {
        configuration.listenPortNumber
    }
    
    private var configuration: Configuration {
        Configuration.shared
    }
    
    private var server = HttpServer()
    private let messageQueue = DispatchQueue(label: "IoriAyameServerMessage")
    let registerQueue = DispatchQueue(label: "IoriAyameServerRegister")
    let unregisterQueue = DispatchQueue(label: "IoriAyameServerUnregister")
    let forwardQueue = DispatchQueue(label: "IoriAyameServerForward")
    
    private var queues: [DispatchQueue] {
        [messageQueue, registerQueue, unregisterQueue, forwardQueue]
    }
    
    private var _rooms: [String: Room] = [:]
    private var _connections: [Int: Connection] = [:]
    
    private static var isInitialized = false
    
    // MARK: - 初期化
    
    private init() {
        for queue in queues {
            queue.suspend()
        }
    }
    
    var rooms: [Room] {
        Array(_rooms.values)
    }
    
    func room(for id: String) -> Room? {
        _rooms[id]
    }
    
    func addRoom(_ room: Room) {
        _rooms[room.roomId] = room
    }
    
    func removeRoom(_ room: Room) {
        for connection in room.connections {
            _connections.removeValue(forKey: connection.webSocket.hashValue)
        }
        _rooms.removeValue(forKey: room.roomId)
    }
    
    var connections: [Connection] {
        Array(_connections.values)
    }
    
    func connection(for id: String) -> Connection? {
        _connections.values.first {
            $0.connectionId.string == id
        }
    }
    
    func connection(for webSocket: WebSocketSession) -> Connection? {
        _connections[webSocket.hashValue]
    }
    
    func unregisterConnection(_ connection: Connection) {
        guard connection.isRegistered else {
            Log.iori.debug("unregister: connection is already unregistered => \(connection.clientId)")
            return
        }
        unregisterQueue.async {
            self._unregisterConnection(connection)
        }
    }
    
    private func _unregisterConnection(_ connection: Connection) {
        Log.iori.debug("unregister connection => \(connection.connectionId)")
        connection.destination?.disconnect()
        connection.debugLog("REMOVED-CLIENT")
        removeRoom(connection.room)
        connection.debugLog("DELETED-ROOM")
    }
    
    public func start(configuration: Configuration? = nil,
                      completionHandler: ((Error?) -> Void)? = nil) {
        guard let configuration = configuration ?? Configuration.load() else {
            completionHandler?(IoriError.configurationFailed)
            return
        }
        Configuration.shared = configuration
        
        if !AyameServer.isInitialized {
            Log.start()
            AyameServer.isInitialized = true
        }
        
        Log.ayame.info("IoriVersion version=\(AyameServer.version)")
        Configuration.shared.debugLog()
        
        Log.iori.info("start server => \(host):\(port)")
        for queue in queues {
            queue.resume()
        }
        
        server.listenAddressIPv4 = host
        server["/signaling"] = websocket(text: { wsSession, text in
            self.handle(text, in: wsSession)
        }, binary: { connection, binary in
            Log.ayame.error("InvalidJSON rawMessage=\(binary)")
        }, disconnected: { wsSession in
            self.onDisconnectWebSocket(wsSession)
        })
        
        do {
            state = .running
            try server.start(in_port_t(port))
            completionHandler?(nil)
        } catch let error {
            Log.iori.info("failed to start server => \(error)")
            completionHandler?(error)
        }
    }
    
    public func stop() {
        Log.iori.info("stop server")
        state = .ready
        server.stop()
        for queue in queues {
            queue.suspend()
        }
    }
    
    public func shutdown() {
        stop()
        Log.iori.info("shutdown server")
        server = HttpServer()
    }
    
    private func onDisconnectWebSocket(_ wsSession: WebSocketSession) {
        guard let connection = self.connection(for: wsSession) else {
            return
        }
        
        connection.disconnect()
    }
    
    private func handle(_ text: String, in wsSession: WebSocketSession) {
        self.messageQueue.async {
            self._handle(text, in: wsSession)
        }
    }
    
    private func _handle(_ text: String, in wsSession: WebSocketSession) {
        Log.iori.debug("received message")
        
        guard let message = Message.from(text) else {
            Log.ayame.error("UnexpectedJSON rawMessage=\(text)")
            return
        }
        
        _handle(message, rawMessage: text, in: wsSession)
    }
    
    private func _handle(_ message: Message, rawMessage: String, in wsSession: WebSocketSession) {
        if let connection = connection(for: wsSession) {
            connection.handle(message, rawMessage: rawMessage)
        } else if message.type == .register {
            Log.signaling.debug("type=\(message.type.rawValue) rawMessage=\(rawMessage)")
            registerQueue.async {
                self.onRegister(message, in: wsSession)
            }
        } else {
            // 未登録の WebSocket 接続で type: register 以外が来た場合
            send(Message.Builder.reject(reason: "invalid"), in: wsSession)
        }
    }
    
    func send(_ message: Message, in webSocket: WebSocketSession, completionHandler: ((Error?) -> Void)? = nil) {
        guard let text = message.jsonText() else {
            let error = IoriError.invalidJSON
            Log.ayame.error("FailedToSendMsg msg=\(message) error: \(error)")
            completionHandler?(error)
            return
        }
        
        Log.iori.debug("send message => \(text)")
        webSocket.writeText(text) { error in
            if error != nil {
                Log.ayame.error("FailedWriteMessage error: \(error!)")
            }
            Log.signaling.debug("\(message) rawMessage: \(text)")
            completionHandler?(nil)
        }
    }
    
    private func onRegister(_ message: Message, in wsSession: WebSocketSession) {

        guard let roomId = message.roomId else {
            Log.ayame.error("MissingRoomID", rawMessage: message)
            return
        }
        
        let room = self.room(for: roomId) ?? Room(roomId: roomId)
        let connection = Connection(webSocket: wsSession, room: room, clientId: message.clientId)
        
        if Configuration.shared.authnWebHookURL != nil {
            postAuthnRequest(message, for: connection) { response, error in
                print("# post authn response")
                guard error == nil else {
                    connection.webhookErrorLog("AuthnWebhookError", error: error, at: (#file, #line))
                    connection.sendReject(reason: "InternalServerError")
                    return
                }
                guard let response = response else {
                    connection.webhookErrorLog("AuthnWebhookError", error: error, at: (#file, #line))
                    connection.sendReject(reason: "InternalServerError")
                    return
                }
                guard response.allowed == true else {
                    if let reason = response.reason {
                        connection.sendReject(reason: reason)
                    } else {
                        connection.webhookErrorLog("AuthnWebhookResponseError", error: error, at: (#file, #line))
                        connection.sendReject(reason: "InternalServerError")
                    }
                    return
                }
                
                // TODO: iceServers, authzMetadata
                
                self.register(message, connection: connection, to: room, in: wsSession)
            }
        } else {
            register(message, connection: connection, to: room, in: wsSession)
        }
    }
    
    private func postAuthnRequest(_ message: Message,
                                  for connection: Connection,
                                  completionHandler: @escaping (Webhook.Response?, Error?) -> Void) {
        //print("# try postAuthnRequest to \(url.absoluteString)")
        let request = Webhook.Request.authn(roomId: message.roomId!,
                                            clientId: connection.clientId,
                                            signalingKey: message.signalingKey,
                                            authnMetadata: message.authnMetadata,
                                            ayameClient: message.ayameClient,
                                            libwebrtc: message.libwebrtc,
                                            environment: message.environment)
        let config = Configuration.shared
        Webhook.postRequest(request,
                            to: config.authnWebHookURL!,
                            httpResponseHandler: { _, response, log in
                                guard response.statusCode == 200 else {
                                    let error = IoriError.authnWebhookUnexpectedStatusCode
                                    connection.webhookErrorLog(error.description, value: ("resp", log), at: (#file, #line))
                                    completionHandler(nil, error)
                                    return false
                                }
                                return true
                            }
                            ) { response, error in
            guard error == nil else {
                print("# error => \(error)")
                completionHandler(nil, error)
                return
            }

            completionHandler(response, nil)
        }
    }

    private func addConnection(_ connection: Connection, to room: Room) {
        _connections[connection.webSocket.hashValue] = connection
        room.add(connection)
    }
    
    private func register(_ message: Message,
                          connection: Connection,
                          to room: Room,
                          in wsSession: WebSocketSession) {
        if room.isRegistered {
            registerTwo(message, connection: connection, to: room, in: wsSession)
        } else {
            registerOne(message, connection: connection, to: room, in: wsSession)
        }
        updateStatistics()
    }

    private func registerOne(_ message: Message,
                             connection: Connection,
                             to room: Room,
                             in wsSession: WebSocketSession) {
        addRoom(room)
        addConnection(connection, to: room)
        room.state = .registerOne
        
        Log.iori.info("room \(room.roomId): create new room")
        connection.debugLog("CREATED-ROOM")
        
        connection.debugLog("REGISTERED-ONE")
        connection.sendAccept(iceServers: [], isExistClient: false)
        connection.pingMonitor.start()
        room.state = .waitRegisterTwo
    }
    
    private func registerTwo(_ message: Message,
                             connection: Connection,
                             to room: Room,
                             in wsSession: WebSocketSession) {
        guard room.hasSpace else {
            Log.iori.info("room \(room.roomId): no space")
            connection.errorLog("RoomFilled")
            connection.sendReject(reason: "full")
            return
        }
        
        Log.iori.debug("room \(room.roomId): state => \(room.state)")
        switch room.state {
        case .waitRegisterTwo:
            connection.debugLog("REGISTERED-TWO")
            room.state = .registerTwo
            addConnection(connection, to: room)
            let accept = Message.Builder.accept(iceServers: [], isExistClient: true)
            connection.send(accept)
            room.state = .waitOfferTwo
        default:
            break
        }
    }
    
    func forward(_ message: Message, to: Connection) {
        forwardQueue.async {
            to.send(message)
        }
    }
    
    private func onDisconnect(in wsSession: WebSocketSession) {
        guard let connection = connection(for: wsSession) else {
            return
        }
        connection.disconnect()
        updateStatistics()
    }
    
    // MARK: - 統計情報
    
    public var onStatistics: ((Statistics) -> Void)?
    
    public var statistics: Statistics {
        Statistics(rooms: _rooms.count, connections: _connections.count)
    }
    
    private func updateStatistics() {
        onStatistics?(statistics)
    }
    
}

public struct Statistics {
    public let rooms: Int
    public let connections: Int
}
