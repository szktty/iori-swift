import Foundation
import Swifter
import Base32
import Puppy

class ConnectionID {
    
    let uuid: UUID
    let string: String
    
    init() {
        let id = UUID()
        uuid = id
        var data = Data()
        data.append(contentsOf: [
                        id.uuid.0, id.uuid.1, id.uuid.2, id.uuid.3,
                        id.uuid.4, id.uuid.5, id.uuid.6, id.uuid.7,
                        id.uuid.8, id.uuid.9, id.uuid.10, id.uuid.11,
                        id.uuid.12, id.uuid.13, id.uuid.14, id.uuid.15])
        string = String(data: Base32.encode(data), encoding: .utf8)!
    }
    
}

extension ConnectionID: Equatable {
    
    static func == (lhs: ConnectionID, rhs: ConnectionID) -> Bool {
        lhs.uuid == rhs.uuid
    }
    
}

extension ConnectionID: CustomStringConvertible {
    
    var description: String {
        string
    }
    
}

class Connection {
    
    enum State {
        case available
        case disconnected
    }
    
    let connectionId: ConnectionID
    let room: Room
    let clientId: String
    private(set) var state: State = .available
    
    var isRegistered: Bool {
        server.connection(for: connectionId.string) != nil
    }

    // もう一人のクライアント
    var destination: Connection? {
        room.connections.first { $0.connectionId != connectionId }
    }
    
    let webSocket: WebSocketSession
    
    private var server: AyameServer {
        AyameServer.shared
    }
    
    private let mainQueue = DispatchQueue(label: "IoriConnectionMain")
    private let forwardQueue = DispatchQueue(label: "IoriConnectionForward")
    var pingMonitor: PingMonitor!
    
    init(webSocket: WebSocketSession, room: Room, clientId: String?) {
        self.webSocket = webSocket
        self.room = room
        let id = ConnectionID()
        connectionId = id
        self.clientId = clientId ?? id.string
        pingMonitor = PingMonitor(connection: self)
    }
    
    func disconnect(reason: Error? = nil) {
        guard state == .available else {
            Log.iori.debug("connection \(connectionId) is already disconnected")
            return
        }
        state = .disconnected

        pingMonitor.stop()
        forwardQueue.suspend()
        
        if let destination = destination {
            debugLog("UNREGISTERED")
            destination.sendBye()
        }
        
        server.unregisterConnection(self)
        debugLog("UNREGISTER")
        debugLog("EXIT-MAIN")
        closeWebSocket()
        debugLog("CLOSED-WS")
        debugLog("EXIT-WS-RECV")
        postDisconnectWebhook { error in
            guard error == nil else {
                self.webhookErrorLog("DisconnectWebhookError", error: error!, at: (#file, #line))
                return
            }
        }
    }
    
    private func closeWebSocket() {
        webSocket.writeCloseFrame() { error in
            guard error == nil else {
                self.debugLog("FAILED-SEND-CLOSE-MESSAGE", error: error)
                return
            }
            self.debugLog("SENT-CLOSE-MESSAGE")
        }
    }
    
    private func postDisconnectWebhook(completionHandler: @escaping (Error?) -> Void) {
        guard let url = Configuration.shared.disconnectWebHookURL else {
            return
        }

        let request = Webhook.Request.disconnect(roomId: room.roomId, clientId: clientId, connectionId: connectionId.string)
        Webhook.postRequest(request, to: url,
                            httpResponseHandler: { _, response, log in
                                guard response.statusCode == 200 else {
                                    self.webhookErrorLog("DisconnectWebhookUnexpectedStatusCode", value: ("resp", log), at: (#file, #line))
                                    completionHandler(IoriError.disconnectWebhookUnexpectedStatusCode)
                                    return false
                                }
                                return true
                            }) { response, error in
            guard error == nil else {
                self.webhookErrorLog("DiconnectWebhookError", error: error!, at: (#file, #line))
                completionHandler(error)
                return
            }
            
            self.webhookLog(("disconnectReq", request))
            completionHandler(nil)
        }
    }
    
    func handle(_ message: Message, rawMessage: String) {
        self.mainQueue.async {
            self._handle(message, rawMessage: rawMessage)
        }
    }
    
    private func _handle(_ message: Message, rawMessage: String) {
        Log.iori.debug("received message type => \(message.type)")

        switch message.type {
        case .register:
            Log.iori.debug("connection is already registered => \(connectionId)")
            errorLog("InternalServer", rawMessage: rawMessage)
        case .offer, .answer, .candidate:
            guard isRegistered else {
                errorLog("RegistrationIncomplete")
                return
            }
            forward(message)
        case .pong:
            pingMonitor.didReceivePong()
        default:
            errorLog("InvalidMessageType")
        }
    }
    
    private func onAnswer(_ message: Message) {
        switch room.state {
        case .waitAnswerOne:
            guard let destination = destination else {
                Log.iori.info("no another client")
                return
            }
            
            room.state = .answerOne
            Log.iori.info("room \(room.roomId): forward answer from first client to second client")
            destination.send(message)
            room.state = .active
        default:
            break
        }
    }
    
    private func onCandidate(_ message: Message) {
        guard let destination = destination else {
            Log.iori.debug("not found destination to forward candidate")
            return
        }
        Log.iori.info("forward candidate to \(destination.clientId)")
        
        forward(message)
    }
    
    func send(_ message: Message, completionHandler: ((Error?) -> Void)? = nil) {
        server.send(message, in: webSocket, completionHandler: completionHandler)
    }
    
    // TODO: authzMetadata
    func sendAccept(iceServers:[IceServer], isExistClient: Bool) {
        send(Message.Builder.accept(iceServers: iceServers, isExistClient: isExistClient, authzMetadata: nil)) { error in
            guard error == nil else {
                self.errorLog("FailedSendAcceptMessage", error: error)
                return
            }
        }
    }
    
    func sendReject(reason: String) {
        send(Message.Builder.reject(reason: reason)) { error in
            guard error == nil else {
                self.errorLog("FailedSendRejectMessage", error: error)
                return
            }
        }
    }
    
    func sendPing() {
        send(Message.Builder.ping()) { error in
            guard error == nil else {
                self.pingMonitor.stop()
                return
            }
        }
    }
    
    func sendBye() {
        send(Message.Builder.bye()) { error in
            guard error == nil else {
                self.errorLog("FailedSendByeMessage", error: error)
                return
            }
        }
        debugLog("SENT-BYE-MESSAGE")
    }
    
    func forward(_ message: Message) {
        if let destination = destination {
            server.forward(message, to: destination)
        }
    }
    
    // MARK: - ログ出力
    
    var logDescription: String {
        "clientID=\(clientId) connectionId=\(connectionId.string) roomId=\(room.roomId)"
    }
    
    private func basicLog(with logger: Puppy, level: LogLevel, _ message: String? = nil, error: Error? = nil, rawMessage: String? = nil, value: (String, Any)? = nil, at caller: (String, UInt)? = nil) {
        var s = ""
        if let (file, line) = caller {
            s += "\(file.components(separatedBy: "/").last!):\(line) > "
        }
        if let message = message {
            s += "\(message) "
        }
        if let error = error {
            s += "error=\(error) "
        }
        if let rawMessage = rawMessage {
            s += "rawMessage=\(rawMessage) "
        }
        if let (name, value) = value {
            s += "\(name)=\(value) "
        }
        s += "\(logDescription) "
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch level {
        case .info:
            logger.info(s)
        case .debug:
            logger.debug(s)
        case .error:
            logger.error(s)
        default:
            logger.info(s)
        }
    }
    
    func infoLog(_ message: String,  at caller: (String, UInt)? = nil) {
        basicLog(with: Log.ayame, level: .info, message, at: caller)
    }
    
    func debugLog(_ message: String, error: Error? = nil,  at caller: (String, UInt)? = nil) {
        basicLog(with: Log.ayame, level: .debug, message, error: error, at: caller)
    }
    
    func errorLog(_ message: String? = nil, error: Error? = nil, rawMessage: String? = nil, value: (String, Any)? = nil,  at caller: (String, UInt)? = nil) {
        basicLog(with: Log.ayame, level: .error, message, error: error, rawMessage: rawMessage, value: value, at: caller)
    }
    
    func signalingLog(_ message: Message, rawMessage: String) {
        guard message.type != .pong else {
            return
        }
        basicLog(with: Log.signaling, level: .debug,
                 "type=\(message.type.rawValue)",
                 rawMessage: rawMessage,
                 at: nil)
    }
    
    func webhookLog(_ value: (String, Any), at caller: (String, UInt)? = nil) {
        basicLog(with: Log.webhook, level: .debug, value: value, at: caller)
    }
    
    func webhookErrorLog(_ message: String, value: (String, Any)? = nil, error: Error? = nil, at caller: (String, UInt)) {
        basicLog(with: Log.webhook, level: .error, message, value: value, at: caller)
    }
    
}

/** :nodoc:
    Swifter の writeText がソケット書き込み時のエラーを潰してしまうので、エラーを呼び出し元に通知するメソッドを追加する
 */
extension WebSocketSession {
    
    private func _encodeLengthAndMaskFlag(_ len: UInt64, _ masked: Bool) -> [UInt8] {
        let encodedLngth = UInt8(masked ? 0x80 : 0x00)
        var encodedBytes = [UInt8]()
        switch len {
        case 0...125:
            encodedBytes.append(encodedLngth | UInt8(len))
        case 126...UInt64(UINT16_MAX):
            encodedBytes.append(encodedLngth | 0x7E)
            encodedBytes.append(UInt8(len >> 8 & 0xFF))
            encodedBytes.append(UInt8(len >> 0 & 0xFF))
        default:
            encodedBytes.append(encodedLngth | 0x7F)
            encodedBytes.append(UInt8(len >> 56 & 0xFF))
            encodedBytes.append(UInt8(len >> 48 & 0xFF))
            encodedBytes.append(UInt8(len >> 40 & 0xFF))
            encodedBytes.append(UInt8(len >> 32 & 0xFF))
            encodedBytes.append(UInt8(len >> 24 & 0xFF))
            encodedBytes.append(UInt8(len >> 16 & 0xFF))
            encodedBytes.append(UInt8(len >> 08 & 0xFF))
            encodedBytes.append(UInt8(len >> 00 & 0xFF))
        }
        return encodedBytes
    }
    
    func writeText(_ text: String, _ completionHandler: ((Error?) -> Void)? = nil) {
        self.writeFrame(ArraySlice(text.utf8), OpCode.text, true, completionHandler)
    }
    
    func writeFrame(_ data: ArraySlice<UInt8>, _ op: OpCode, _ fin: Bool = true, _ completionHandler: ((Error?) -> Void)? = nil) {
        let finAndOpCode = UInt8(fin ? 0x80 : 0x00) | op.rawValue
        let maskAndLngth = _encodeLengthAndMaskFlag(UInt64(data.count), false)
        do {
            try self.socket.writeUInt8([finAndOpCode])
            try self.socket.writeUInt8(maskAndLngth)
            try self.socket.writeUInt8(data)
            completionHandler?(nil)
        } catch {
            completionHandler?(error)
        }
    }
    
    public func writeCloseFrame(_ completionHandler: @escaping ((Error?) -> Void)) {
        writeFrame(ArraySlice("".utf8), .close, true,  completionHandler)
    }
    
}
