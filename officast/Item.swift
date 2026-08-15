//
//  Item.swift
//  officast
//
//  Created by Ginger Marco on 2026/08/15.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
