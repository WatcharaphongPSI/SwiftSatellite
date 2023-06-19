//
//  File.swift
//  
//
//  Created by Watcharaphong.iOS on 25/5/2566 BE.
//

import Foundation

public let myUserDefault      = UserDefaults.standard
public let key_isIpDevice     = "userDefault_isIpDevice"

public class M_UserBluetooth {
    
    public var userTitleName       : String
    public var userIpDevice        : String
    public var userServiceUUIDs    : String
    public var userWaveStatus      : String
    public var userStatus          : String
    public var userConnected       : Bool
    
    public var userPeripheral      : Peripheral
    public var userRSSI            : Int
    
    public init(userTitleName : String, userIpDevice : String, userServiceUUIDs : String, userWaveStatus : String, userStatus : String, userConnected : Bool, userPeripheral : Peripheral, userRSSI : Int) {
        
        self.userTitleName   = userTitleName
        self.userIpDevice    = userIpDevice
        self.userServiceUUIDs = userServiceUUIDs
        self.userWaveStatus  = userWaveStatus
        self.userStatus      = userStatus
        self.userConnected   = userConnected
        
        self.userPeripheral  = userPeripheral
        self.userRSSI        = userRSSI
    }
}
