import Foundation

class Room {
    
    enum State {
        case ready
        case registerOne
        case waitRegisterTwo
        case registerTwo
        case waitOfferTwo
        case secondOffer
        case waitAnswerOne
        case answerOne
        case active
        case closed
    }
    
    let roomId: String
    
    var connections: [Connection] = []
    
    var hasSpace: Bool {
        connections.count < 2
    }
    
    var state: State = .ready
    
    init(roomId: String) {
        self.roomId = roomId
    }
    
    func add(_ connection: Connection) {
        connections.append(connection)
    }
    
    func remove(_ connection: Connection) {
        connections = connections.filter {$0.connectionId != connection.connectionId }
    }
    
    func contains(_ connection: Connection) -> Bool {
        connections.contains { $0.connectionId == connection.connectionId }
    }
    
}
