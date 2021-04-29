import Foundation

enum Webhook {
    
    struct Request: Codable {
        
        // MARK: authn, disconnect
        
        var roomId: String?
        var clientId: String?
        var connectionId: String?
        
        // MARK: authn
        
        var signalingKey: String?
        var authnMetadata: String?
        var ayameClient: String?
        var libwebrtc: String?
        var environment: String?
        
        static func authn(roomId: String,
                          clientId: String,
                          connectionId: String,
                          signalingKey: String?,
                          authnMetadata: String?,
                          ayameClient: String?,
                          libwebrtc: String?,
                          environment: String?) -> Request {
            var request = Request()
            request.roomId = roomId
            request.clientId = clientId
            request.connectionId = connectionId
            request.signalingKey = signalingKey
            request.authnMetadata = authnMetadata
            request.ayameClient = ayameClient
            request.libwebrtc = libwebrtc
            request.environment = environment
            return request
        }
        
        static func disconnect(roomId: String,
                          clientId: String,
                          connectionId: String) -> Request {
            var request = Request()
            request.roomId = roomId
            request.clientId = clientId
            request.connectionId = connectionId
            return request
        }
        
    }
    
    struct Response {
        
        var allowed: Bool?
        var iceServers: [IceServer]?
        var reason: String?
        var authzMetadata: JSON?
        
    }
    
    static func postRequest(_ request: Request, to url: URL,  completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(request)
            
            var httpRequest = URLRequest(url: url)
            httpRequest.httpMethod = "POST"
            httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            httpRequest.httpBody = data
            httpRequest.timeoutInterval = TimeInterval(Configuration.shared.webhookRequestTimeout)
            
            URLSession.shared.dataTask(with: httpRequest) { data, response, error in
                completionHandler(data, response as? HTTPURLResponse, error)
            }.resume()
        } catch let error {
            completionHandler(nil, nil, error)
            return
        }
    }
    
}

/** :nodoc: */
extension Webhook.Request: CustomStringConvertible {
    
    var description: String {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            guard let text = String(data: data, encoding: .utf8) else {
                return "<invalid>"
            }
            return text
        } catch let error {
            return "<\(error)>"
        }
    }
    
}
