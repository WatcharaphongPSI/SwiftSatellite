//
//  BT_Manager.swift
//  
//
//  Created by Watcharaphong.iOS on 25/5/2566 BE.
//

import UIKit
import Foundation

public class BT_Manager: UIViewController {
    
    var isPeripheral       : Peripheral!
    
    var myBluetoothList    = [M_UserBluetooth]()
    var myBluetoothListCC  : M_UserBluetooth!
    
    var myDataToBox        = [Data]()
    
    var timerTest          : Timer?
    var isNumber           = 0
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
//MARK: Setup Search device ---------------------

    public func setupScan_BT(isSatelliteType : String, completion: @escaping ([M_UserBluetooth])->Void) {

        myBluetoothList.removeAll()

        print("Working Search...")
        
        scanForPeripherals(withServiceUUIDs: nil, timeoutAfter: 3) { [self] scanResult in
            switch scanResult {

            case .scanStarted: break

            case .scanResult(let peripheral, let advertisementData, let RSSI):

                var rssiInt = RSSI ?? 0
                rssiInt.negate()
                
                let getName = String(peripheral.name ?? "")
                let myIpDevice = self.macAddress(advertisementData: advertisementData)
                
                print(String(peripheral.name ?? ""))
                print(getName)
                print(getName.hasPrefix(isSatelliteType))
                
                if (getName.hasPrefix(isSatelliteType)) {
                    
                    print(getName.hasPrefix(isSatelliteType))
                    
                    myBluetoothList = setupAppendBluetoothList(peripheral: peripheral, ipDevice: myIpDevice, rssi: RSSI ?? 0, isConnected: false)
                }

            case .scanStopped:

                DispatchQueue.main.async { [self] in
                    completion(myBluetoothList)
                }
                print("Stop Search")
                break
            }
        }
    }
    
//MARK: Setup Connect ---------------------------
    
    public func setupConnect_BT(peripheral : Peripheral, ipDevice : String, rssi : Int, completion: @escaping (M_UserBluetooth)->Void) {

        print("Connecting...")

        peripheral.connect(withTimeout: 5) { [self] result in
            switch result {
            case .success:

                //Save bluetooth list ------

                myBluetoothListCC = M_UserBluetooth(userTitleName: peripheral.name ?? "", userIpDevice: ipDevice, userServiceUUIDs: "", userWaveStatus: "", userStatus: "", userConnected: true, userPeripheral: peripheral, userRSSI: rssi)
                
                setupRememberConnection(ipDevice: ipDevice)

                print("SUCCESS : Connected -----------------")
                break

            case .failure:
                
                myBluetoothListCC = M_UserBluetooth(userTitleName: peripheral.name ?? "", userIpDevice: ipDevice, userServiceUUIDs: "", userWaveStatus: "", userStatus: "", userConnected: false, userPeripheral: peripheral, userRSSI: rssi)
                
                print("FAIL : Connected -----------------")
                break
            }
            
            DispatchQueue.main.async { [self] in
                completion(myBluetoothListCC)
            }
        }
    }
    
//MARK: Setup DidConnect ------------------------
    
    public func setupDidConnect_BT(peripheral : Peripheral ,completion: @escaping (Bool)->Void) {
        
        var isStatus = Bool()

        peripheral.disconnect { [self] result in
            
            switch result {
            case .success:
                
                print("My IP Device : \(setupGetRememberConnection()) -----------------")
                
                myUserDefault.removeObject(forKey: key_isIpDevice)
                myUserDefault.synchronize()
                
                isStatus = true
                break // You are now connected to the peripheral
            
            case .failure:
                
                isStatus = false
                break // An error happened while connecting
            }
            
            DispatchQueue.main.async {
                completion(isStatus)
            }
        }
    }
    
//MARK: Setup WriteValue ------------------------
    
    public func setupWriteValue_BT(peripheral : Peripheral, link : String, isType : String, completion: @escaping (Bool)->Void) {
        
        var isStatus   = Bool()
        var indexCount = [Int]()
        
        let openComment : [UInt8] = setupDetectHeadingType(isType: isType)
        let closeComment: [UInt8] = [0x5B,0x45,0x5D]
        
        let resultsLength         = link.count/53 + 1

        let lengthCount :[UInt8] = [UInt8(resultsLength)]

        let length      : [UInt8] = lengthCount
        
        let myLink = subLink(link: link, length: resultsLength)
        
        for (indexLoop, element) in myLink.enumerated() {
            
            indexCount.append(1)
            
            let indexPath   : [UInt8] = [UInt8(indexCount.count)]
            let index       : [UInt8] = indexPath
            
            let arrayLink: [UInt8] = Array(element.utf8)
            
            let sum = 2 + arrayLink.count
            let paramLength:[UInt8] = [UInt8(bitPattern: Int8(sum))]

            let complete: [UInt8] = openComment + paramLength + length + index + arrayLink + closeComment
            let myData = Data(complete)
            
            if indexCount.count == 1 {

                sendWriteValue(peripheral: peripheral, results: myData)
                isStatus = true
                
                if myLink.count == 1 { //This case link < 53 -------
                    
                    DispatchQueue.main.async {
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [] in

                            print("SUCCESS : Write result")
                        }
                        
                        completion(isStatus)
                    }
                }

            } else {
  
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in

                    sendWriteValue(peripheral: peripheral, results: myData)
                    isStatus = true

                    if indexLoop == myLink.endIndex - 1 {

                        DispatchQueue.main.async {

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [] in

                                print("SUCCESS : Write result")
                            }

                            completion(isStatus)
                        }
                    }
                }
            }
        }
    }
    
//MARK: Setup Write Sync PlayList ------------------------
    
    public func setupWrite_SyncYoutubePlayList_BT(peripheral : Peripheral, link : String, isType : String, completion: @escaping (Bool)->Void) {
        
        isPeripheral = peripheral
    
        let myDataLink = Data(link.utf8)
        
        var isStatus   = Bool()
        var indexCount = [Int]()
        
        let openComment : [UInt8] = setupDetectHeadingType(isType: isType)
        let closeComment: [UInt8] = [0x5B,0x45,0x5D]
        
        let resultsLength         = myDataLink.count/52 + 1

        let lengthCount :[UInt8] = [UInt8(resultsLength)]
        let length      : [UInt8] = lengthCount
        
        let myLink = subLinkData(link: myDataLink, length: resultsLength)
        
        for (_, element) in myLink.enumerated() {
            
            indexCount.append(1)

            let indexPath   : [UInt8] = [UInt8(indexCount.count)]
            let index       : [UInt8] = indexPath

            let bytes = [UInt8](element)

            let arrayLink : [UInt8] = bytes
            
            let sum = 2 + arrayLink.count
            let value : UInt8 = UInt8(sum)
            let paramLength:[UInt8] = [value]

            let complete: [UInt8] = openComment + paramLength + length + index + arrayLink + closeComment
            let myData = Data(complete)
            
            myDataToBox.append(myData)
        }
        
        isStatus = true

        DispatchQueue.main.async {
            completion(isStatus)
        }
        
        print("Total link send to box ------- : \(myDataToBox.count)")
        
        setupSendDataToBox()
    }
    
    func setupSendDataToBox() {
        
        guard self.timerTest == nil else { return }
        self.timerTest = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.sendLinkToBox), userInfo: nil, repeats: true)
    }
    
    func stopTimer() {
        
        guard timerTest != nil else { return }
        timerTest?.invalidate()
        timerTest = nil
    }
    
    @objc func sendLinkToBox() {

        if  myDataToBox.count - 1 == isNumber {
        
            print("Final send to box count ------ : \(isNumber)")
            
            sendWriteValue(peripheral: isPeripheral, results: myDataToBox[isNumber])

            NotificationCenter.default.post(name: NSNotification.Name("StopSendingdata"), object: nil)

            stopTimer()
            
        } else {
            
            print("isNumber send : \(isNumber)")
            
            sendWriteValue(peripheral: isPeripheral, results: myDataToBox[isNumber])
            isNumber = isNumber + 1
        }
    }

// END Setup Write Sync PlayList -------------------
    
//MARK: Setup Function----------------------------
    
    func setupAppendBluetoothList(peripheral : Peripheral, ipDevice : String, rssi : Int, isConnected : Bool) -> [M_UserBluetooth] {
        
        print("List Search Satellite  Box : \(ipDevice.uppercased()) --------")
        
        myBluetoothList.append(M_UserBluetooth(userTitleName: peripheral.name ?? "", userIpDevice: ipDevice, userServiceUUIDs: "", userWaveStatus: "", userStatus: "", userConnected: isConnected, userPeripheral: peripheral, userRSSI: rssi))
        
        return myBluetoothList
    }

    public func macAddress(advertisementData:[String:Any])->String {

        if let manufacturerData = advertisementData["kCBAdvDataManufacturerData"] as? Data {

            let completeMac:String = manufacturerData.hexMacAddrEncodedString()
            return String(completeMac.dropLast())// "Dolphi"
        }
        return ""
    }
    
    func setupDetectHeadingType(isType : String) -> [UInt8] {
        
        if isType == "Link" {
            
            return  [0x5B,0x53,0x5D,0x20,0x03]
            
        } else {
            
            return [0x5B,0x53,0x5D,0x20,0x03,0x00]
        }
    }
    
    func subLink(link : String, length : Int) -> [String] {
        
        var a1  = ""
        var aa1 = ""
        
        var myLink = [String]()
        
        for i in 1...length {
            
            if i == 1 {
                
                (a1,aa1) = subStringIndex(results: link)
                myLink.append(a1)
            } else if i == 2 {
                
                (a1,aa1) = subStringIndex(results: aa1)
                myLink.append(a1)
            } else if i == 3 {
                
                (a1,aa1) = subStringIndex(results: aa1)
                myLink.append(a1)
            } else if i == 4 {
                
                (a1,aa1) = subStringIndex(results: aa1)
                myLink.append(a1)
            } else {
                
                (a1,aa1) = subStringIndex(results: aa1)
                myLink.append(a1)
            }
        }
        
        return myLink
    }
    
    func subLinkData(link : Data, length : Int) -> [Data] {
        
        var a1  = Data()
        var aa1 = Data()
        
        var myLink = [Data]()
        
        for i in 1...length {
            
            if i == 1 {
                
                (a1,aa1) = subDataIndex(results: link)
                myLink.append(a1)
                
            } else if i == 2 {
                
                (a1,aa1) = subDataIndex(results: aa1)
                myLink.append(a1)
                
            } else if i == 3 {
                
                (a1,aa1) = subDataIndex(results: aa1)
                myLink.append(a1)
                
            } else if i == 4 {
                
                (a1,aa1) = subDataIndex(results: aa1)
                myLink.append(a1)
                
            } else {
                
                (a1,aa1) = subDataIndex(results: aa1)
                
                myLink.append(a1)
            }
        }
        return myLink
    }
    
    func subDataIndex(results : Data) -> (Data, Data){
        
        return (results.subData(from: 0, length: 52), results.subData(from: 52))
    }
    
    func subStringIndex(results : String) -> (String, String) {
        
        return (results.substring(from: 0, length: 52), results.substring(from: 52))
    }

    func sendWriteValue(peripheral : Peripheral, results : Data) {
        
        peripheral.writeValue(ofCharacWithUUID: "fff4", fromServiceWithUUID: "fff0", value: results, type: .withoutResponse) {
            result in 
            switch result {
            case .success:
                
                print("------------- Success Send Link ---------------")
                
                break
            
            case .failure(let error):
                
                print(error)
                break // An error happened while writting the data.
            }
        }
    }
    
    public func setupRememberConnection(ipDevice : String) {
        
        myUserDefault.set(ipDevice, forKey: key_isIpDevice)
        myUserDefault.synchronize()
    }
    
    public func setupGetRememberConnection()->String {
        
        return myUserDefault.string(forKey: key_isIpDevice) ?? ""
    }
    
    public func setupDetectConnected()->Bool {

        if myUserDefault.string(forKey: key_isIpDevice) == "" || myUserDefault.string(forKey: key_isIpDevice) == nil {
            
            return false
            
        } else {
            
            return true
        }
    }
}

//MARK: Setup Extension -------------------------

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    func hexMacAddrEncodedString() -> String {
        return map { String(format: "%02hhx:", $0) }.joined()
    }
    
    //Setup Sub Data ----------------------
    
    func subData(from: Int?, to: Int?) -> Data {
        if let start = from {
            guard start < self.count else {
                return Data()
            }
        }
        
        if let end = to {
            guard end >= 0 else {
                return Data()
            }
        }
        
        if let start = from, let end = to {
            guard end - start >= 0 else {
                return Data()
            }
        }
        
        let startIndex: Data.Index
        if let start = from, start >= 0 {
            startIndex = self.index(self.startIndex, offsetBy: start)
        } else {
            startIndex = self.startIndex
        }
        
        let endIndex: Data.Index
        if let end = to, end >= 0, end < self.count {
            endIndex = self.index(self.startIndex, offsetBy: end + 1)
        } else {
            endIndex = self.endIndex
        }
        
        return Data(self[startIndex ..< endIndex])
    }
    
    func subData(from: Int) -> Data {
        return self.subData(from: from, to: nil)
    }
    
    func subData(to: Int) -> Data {
        return self.subData(from: nil, to: to)
    }
    
    func subData(from: Int?, length: Int) -> Data {
        guard length > 0 else {
            return Data()
        }
        
        let end: Int
        if let start = from, start > 0 {
            end = start + length - 1
        } else {
            end = length - 1
        }
        
        return self.subData(from: from, to: end)
    }
    
    func subData(length: Int, to: Int?) -> Data {
        guard let end = to, end > 0, length > 0 else {
            return Data()
        }
        
        let start: Int
        if let end = to, end - length > 0 {
            start = end - length + 1
        } else {
            start = 0
        }
        
        return self.subData(from: start, to: to)
    }
}

extension String {
    func substring(from: Int?, to: Int?) -> String {
        if let start = from {
            guard start < self.count else {
                return ""
            }
        }
        
        if let end = to {
            guard end >= 0 else {
                return ""
            }
        }
        
        if let start = from, let end = to {
            guard end - start >= 0 else {
                return ""
            }
        }
        
        let startIndex: String.Index
        if let start = from, start >= 0 {
            startIndex = self.index(self.startIndex, offsetBy: start)
        } else {
            startIndex = self.startIndex
        }
        
        let endIndex: String.Index
        if let end = to, end >= 0, end < self.count {
            endIndex = self.index(self.startIndex, offsetBy: end + 1)
        } else {
            endIndex = self.endIndex
        }
        
        return String(self[startIndex ..< endIndex])
    }
    
    func substring(from: Int) -> String {
        return self.substring(from: from, to: nil)
    }
    
    func substring(to: Int) -> String {
        return self.substring(from: nil, to: to)
    }
    
    func substring(from: Int?, length: Int) -> String {
        guard length > 0 else {
            return ""
        }
        
        let end: Int
        if let start = from, start > 0 {
            end = start + length - 1
        } else {
            end = length - 1
        }
        
        return self.substring(from: from, to: end)
    }
    
    func substring(length: Int, to: Int?) -> String {
        guard let end = to, end > 0, length > 0 else {
            return ""
        }
        
        let start: Int
        if let end = to, end - length > 0 {
            start = end - length + 1
        } else {
            start = 0
        }
        
        return self.substring(from: start, to: to)
    }
}
