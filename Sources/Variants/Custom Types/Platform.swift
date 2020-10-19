//
// Copyright © 2020 Backbase R&D B.V. All rights reserved.
//

import Foundation
import ArgumentParser

enum Platform: String, ExpressibleByArgument, Codable {
    case ios
    case android
    case unknown
}
