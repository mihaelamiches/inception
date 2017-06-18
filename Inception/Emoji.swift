//
//  Emoji.swift
//  Inception
//
//  Created by Mihaela Miches on 6/15/17.
//  Copyright © 2017 me. All rights reserved.
//


public struct Emoji: Decodable {
    let id: Int
    let code: String
    let value: String
    let description: String
    let tags: [String]
    
    init?(from: [String: Any]) {
        guard let id = from["id"] as? Int,
            let code = from["code"] as? String,
            let value = from["value"] as? String,
            let description = from["description"] as? String,
            let tags = from["tags"] as? [String] else { return nil }
        
        self.id = id
        self.code = code
        self.value = value
        self.tags = tags
        self.description = description
    }
}

