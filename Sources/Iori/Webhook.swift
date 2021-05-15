import Foundation

enum Webhook {
    
    struct Request: Codable {
        
        // MARK: authn, disconnect
        
        var roomId: String?
        var clientId: String?
        var connectionId: String?
        
        // MARK: authn
        
        var signalingKey: String?
        var authnMetadata: JSON?
        var ayameClient: String?
        var libwebrtc: String?
        var environment: String?
        
        static func authn(roomId: String,
                          clientId: String,
                          signalingKey: String? = nil,
                          authnMetadata: JSON? = nil,
                          ayameClient: String? = nil,
                          libwebrtc: String? = nil,
                          environment: String? = nil) -> Request {
            var request = Request()
            request.roomId = roomId
            request.clientId = clientId
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
    
    struct Response: Codable {
        
        var allowed: Bool?
        var iceServers: [IceServer]?
        var reason: String?
        var authzMetadata: JSON?
        
    }
    
    // TODO: timeout
    static func postRequest(_ request: Request,
                            to url: URL,
                            timeout: Int? = nil,
                            httpResponseHandler: ((Data?, HTTPURLResponse, [String: Any]) -> Bool)? = nil,
                            completionHandler: @escaping (Response?, Error?) -> Void) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(request)
            
            var httpRequest = URLRequest(url: url)
            httpRequest.httpMethod = "POST"
            httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            httpRequest.httpBody = data
            
            let timeout = timeout ?? Configuration.shared.webhookRequestTimeout
            httpRequest.timeoutInterval = TimeInterval(timeout)
            
            URLSession.shared.dataTask(with: httpRequest) { data, urlResponse, error in
                guard error == nil else {
                    completionHandler(nil, error)
                    return
                }
                guard let httpResponse = urlResponse as? HTTPURLResponse else {
                    completionHandler(nil, IoriError.internalServer)
                    return
                }
                
                let body: String
                if let data = data {
                    body = String(data: data, encoding: .utf8) ?? ""
                } else {
                    body = ""
                }
                
                if let handler = httpResponseHandler {
                    let log: [String: Any] = [
                        "status": httpResponse.statusCode,
                        "header": httpResponse.allHeaderFields as? [String: Any] ?? [],
                        "body": body]
                    if !handler(data, httpResponse, log) {
                        return
                    }
                }
                
                guard let response = JSON.decode(body, to: Response.self) else {
                    // TODO
                    fatalError()
                }
                
                completionHandler(response, nil)
            }.resume()
        } catch let error {
            completionHandler(nil, error)
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
