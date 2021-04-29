import Foundation

enum IoriError: String, Error {
    
    case configurationFailed = "ConfigurationFailed"
    case serverStartFailed = "ServerStartFailed"
    
    case invalidMessageType = "InvalidMessageType"
    case missingRoomID = "MissingRoomID"
    case missingClientID = "MissingClientID"
    case invalidJSON = "InvalidJSON"
    case unexpectedJSON = "UnexpectedJSON"
    case registrationIncomplete = "RegistrationIncomplete"
    case authnWebhook = "AuthnWebhookError"
    case authnWebhookResponse = "AuthnWebhookResponseError"
    case authnWebhookUnexpectedStatusCode = "AuthnWebhookUnexpectedStatusCode"
    case authnWebhookReject = "AuthnWebhookReject"
    case disconnectWebhook = "DisconnectWebhookError"
    case disconnectWebhookResponse = "DisconnectWebhookResponseError"
    case disconnectWebhookUnexpectedStatusCode = "DisconnectWebhookUnexpectedStatusCode"
    case configInvalidLogLevel = "ConfigInvalidLogLevel"
    case roomFull = "RoomFull"
    case internalServer = "InternalServer"
    case pongTimeout
    
}

extension IoriError: CustomStringConvertible {
    
    var description: String {
        self.rawValue
    }
    
}
