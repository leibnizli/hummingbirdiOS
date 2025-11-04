//
//  Item.swift
//  hummingbird
//
//  Created by admin on 2025/11/4.
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
