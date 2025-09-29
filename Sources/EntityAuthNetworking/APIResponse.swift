import Foundation

public struct APIResponse<T: Decodable>: Decodable {
    public let data: T
}
