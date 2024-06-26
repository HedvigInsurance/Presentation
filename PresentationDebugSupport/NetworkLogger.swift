//
//  File.swift
//  
//
//  Created by Sam Pettersson on 2021-07-28.
//

import Foundation

struct NetworkEntry: Codable {
    var timestamp: Double
    var url: String
    var response: String
    var responseCode: Int
}

class NetworkLogger: Codable {
    var entries: [NetworkEntry] = []
    
    init() {}
    
    func logTask(_ task: URLSessionDataTask, data: Data) {
        var statusCode = 0
        
        if let httpResponse = task.response as? HTTPURLResponse {
            statusCode = httpResponse.statusCode
        }
        
        let entry = NetworkEntry(
            timestamp: Date().timeIntervalSince1970,
            url: task.originalRequest?.url?.absoluteString ?? "",
            response: String(data: data, encoding: .utf8) ?? "",
            responseCode: statusCode
        )
        
        entries.insert(entry, at: 0)
    }
}
