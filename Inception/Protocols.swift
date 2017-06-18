//
//  Protocols.swift
//  Inception
//
//  Created by Mihaela Miches on 6/10/17.
//  Copyright © 2017 me. All rights reserved.
//

import UIKit

typealias Emojified = (label: String, emoji: String)

enum AnchorType { case emoji, about}

enum MLModelInput {
    case inception, googlePlaces
    
    func size() -> CGSize {
        switch self {
        case .inception: return CGSize(width: 299, height: 299)
        case .googlePlaces: return CGSize(width: 224, height: 224)
        }
    }
}

