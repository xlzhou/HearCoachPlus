//
//  Item.swift
//  HearCoachPlus
//
//  Created by 周晓凌 on 2025/8/31.
//

import Foundation

#if canImport(SwiftData) && !SKIP_MACROS
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
#endif
