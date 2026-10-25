//
//  Item.swift
//  Bound
//
//  Created by Ritika Joshi on 10/24/26.
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
