import Foundation

struct IceCandidate: Codable {
    var candidate: String
    var sdpMid: String
    var sdpMLineIndex: Int
}

struct IceServer: Codable {
    
    static let `default` = IceServer(urls: [URL(string: "stun:stun.l.google.com:19302")!])
    
    var urls: [URL] = []
    
}

struct IceTransportPolicy: Codable {
    
}
