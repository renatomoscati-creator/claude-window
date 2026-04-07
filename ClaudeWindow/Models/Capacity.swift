import Foundation

struct QueryCapacity: Codable, Equatable {
    let minQueries: Int
    let maxQueries: Int
    let minTokens: Int
    let maxTokens: Int
    let confidence: Confidence
}

struct BestWindow: Codable, Equatable {
    let startHour: Int      // UTC hour 0-23
    let endHour: Int        // UTC hour 0-23
    let confidence: Confidence
    let reasons: [String]
}
