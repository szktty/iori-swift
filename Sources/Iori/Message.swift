import Foundation

struct Message: Codable {

    enum MessageType: String, Codable {
        case register
        case accept
        case reject
        case offer
        case answer
        case candidate
        case bye
        case ping
        case pong
    }
    
    var type: MessageType
    var roomId: String?
    var clientId: String?
    var key: String?
    var authnMetadata: JSON?
    var authzMetadata: JSON?
    var signalingKey: String?
    var ayameClient: String?
    var isExistUser: Bool?
    var isExistClient: Bool?
    var allowed: Bool?
    var reason: String?
    var sdp: String?
    var ice: IceCandidate?
    var iceServers: [IceServer]?
    var environment: String?
    var libwebrtc: String?

    init(type: MessageType) {
        self.type = type
    }
    
    enum Builder {
        
        static func register(roomId: String, clientId: String,
                                    signalingKey: String? = nil,
                                    authnMetadata: JSON? = nil) -> Message {
            var message = Message(type: .register)
            message.roomId = roomId
            message.clientId = clientId
            message.signalingKey = signalingKey
            message.authnMetadata = authnMetadata
            return message
        }
        
        static func accept(iceServers: [IceServer], isExistClient: Bool,
                                  authzMetadata: JSON? = nil) -> Message {
            var message = Message(type: .accept)
            message.iceServers = iceServers
            message.isExistUser = isExistClient
            message.isExistClient = isExistClient
            message.authzMetadata = authzMetadata
            return message
        }
        
        static func offer(sdp: String) -> Message {
            var message = Message(type: .offer)
            message.sdp = sdp
            return message
        }
        
        static func answer(sdp: String) -> Message {
            var message = Message(type: .answer)
            message.sdp = sdp
            return message
        }
        
        static func ping() -> Message {
            .init(type: .ping)
        }
        
        static func pong() -> Message {
            .init(type: .pong)
        }
        
        static func reject(reason: String) -> Message {
            var message = Message(type: .reject)
            message.reason = reason
            return message
        }
        
        static func bye() -> Message {
            Message(type: .bye)
        }
    }
    
}

struct JSON: Codable {
    
    private var encodable: Encodable?
    
    var value: Any?
    
    init(value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {}
    
    func encode(to encoder: Encoder) throws {
        try encodable?.encode(to: encoder)
    }
    
    mutating func setEncodableValue(_ value: Encodable) {
        self.encodable = value
        self.value = value
    }
    
}