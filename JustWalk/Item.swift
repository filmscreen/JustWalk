//
//  Item.swift
//  JustWalk
//
//  Created by Randy Chia on 1/23/26.
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
