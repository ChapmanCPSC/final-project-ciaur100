//
//  CPStruct.swift
//  Chapman Parking
//
//  Created by Stephen Ciauri on 5/13/16.
//  Copyright © 2016 Stephen Ciauri. All rights reserved.
//

import Foundation

//protocol CPReport{
//    var structures
//}

protocol CPReport{
    var structures: [CPStructure] {get}
}

protocol CPStructure{
    var name: String? {get}
    var levels: [CPLevel] {get}
    var lat: Double? {get}
    var long: Double? {get}
}

protocol CPLevel{
    var name: String? {get}
    var capacity: Int? {get}
    var counts: [CPCount] {get}
}

protocol CPCount{
    var count: Int? {get}
    var timestamp: NSDate? {get}
}