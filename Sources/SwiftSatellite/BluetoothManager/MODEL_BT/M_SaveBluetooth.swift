//
//  File.swift
//  
//
//  Created by Watcharaphong.iOS on 26/6/2566 BE.
//

import Foundation

class M_SaveBluetooth : Codable {
    
    var userTitleName       : String
    var userIpDevice        : String
    var userServiceUUIDs    : String
    var userWaveStatus      : String
    var userStatus          : String

    var rssi                : Int
    
    init(userTitleName : String, userIpDevice : String, userServiceUUIDs : String, userWaveStatus : String, userStatus : String, rssi : Int) {
        
        self.userTitleName   = userTitleName
        self.userIpDevice    = userIpDevice
        self.userServiceUUIDs = userServiceUUIDs
        self.userWaveStatus  = userWaveStatus
        self.userStatus      = userStatus
        
        self.rssi            = rssi
    }
}

