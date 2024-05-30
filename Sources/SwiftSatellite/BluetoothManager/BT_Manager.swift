//
//  BT_Manager.swift
//  
//
//  Created by Watcharaphong.iOS on 25/5/2566 BE.
//

import UIKit
import Foundation
import CoreBluetooth

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
                
                if (getName.hasPrefix(isSatelliteType)) {

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
                
                setupNotify(isPeripheral: peripheral)

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

                sendWriteValue_BT(peripheral: peripheral, results: myData)
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

                    sendWriteValue_BT(peripheral: peripheral, results: myData)
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
    
    public func setupWriteValueSatellite_BT(peripheral : Peripheral, isNumber : Int) {
        
        let openComment : [UInt8] = [0x5B,0x53,0x5D,0x20,0x01,0x00,0x03]
        let closeComment: [UInt8] = [0x5B,0x45,0x5D]
        
        let newResults = String(format: "%03d", isNumber)
        let arrayNumber : [UInt8] = Array(newResults.utf8)
        
        let complete: [UInt8] = openComment + arrayNumber + closeComment
        let myData            = Data(complete)

        sendWriteValue_BT(peripheral: peripheral, results: myData)
    }
    
    public func setupWriteValueRemote_BT(peripheral : Peripheral, isButton : String) {
        
        let openComment : [UInt8] = [0x5B,0x53,0x5D,0x20,0x02,0x00,0x02,0x00]
        let remoteTouch : [UInt8] = setupDetectTouchRemote(result: isButton)
        let closeComment: [UInt8] = [0x5B,0x45,0x5D]
        
        let complete: [UInt8]     = openComment + remoteTouch + closeComment
        let myData                = Data(complete)
        
        sendWriteValue_BT(peripheral: peripheral, results: myData)
    }
    
    public func setupWriteValueWifiPassword(peripheral : Peripheral,isFuncCommand : [UInt8], isPassword : String) {
        
        let openCommand  : [UInt8]  = [0x5B,0x53,0x5D,0x20]
        let funcCommand  : [UInt8]  = isFuncCommand
        
        let encryption   : [UInt8]  = [0x04]
        let closeCommand : [UInt8]  = [0x5B,0x45,0x5D]
        
        let sum = 1 + isPassword.count
        let paramLeangth : [UInt8]  = Array(byteArray(from: Int8(sum)))
        
        let wifiname     : [UInt8]  = Array(isPassword.utf8)

        print("BT_Manager : Password     : %@", wifiname)
        print("BT_Manager : ParamLength  : %@", paramLeangth)
        
        let complete     : [UInt8]  = openCommand + funcCommand + paramLeangth + encryption + wifiname + closeCommand
        let myData                  = Data(complete)
        
        sendWriteValue_BT(peripheral: peripheral, results: myData)
    }
    
    public func setupWriteValueWifiUsername(peripheral : Peripheral,isFuncCommand : [UInt8], isSSID : String) {

        let openCommand : [UInt8] = [0x5B,0x53,0x5D,0x20]
        let funcCommand  : [UInt8]  = isFuncCommand
        
        let closeCommand : [UInt8] = [0x5B,0x45,0x5D]
        
        let sum = 0 + isSSID.count
        let paramLength:[UInt8] = Array(byteArray(from:Int8(sum)))

        let wifiname : [UInt8] = Array(isSSID.utf8)
        print("BT_Manager : SSID        : %@", wifiname)
        print("BT_Manager : ParamLength : %@", paramLength)

        let complete: [UInt8] = openCommand + funcCommand + paramLength + wifiname + closeCommand
        let myData = Data(complete)
        print("myData : %@", complete)
        
        sendWriteValue_BT(peripheral: peripheral, results: myData)
    }
    
    func byteArray<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
        withUnsafeBytes(of: value.bigEndian, Array.init)
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
            
            sendWriteValue_BT(peripheral: isPeripheral, results: myDataToBox[isNumber])

            NotificationCenter.default.post(name: NSNotification.Name("StopSendingdata"), object: nil)

            stopTimer()
            
        } else {
            
            print("isNumber send : \(isNumber)")
            
            sendWriteValue_BT(peripheral: isPeripheral, results: myDataToBox[isNumber])
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

    public func sendWriteValue_BT(peripheral : Peripheral, results : Data) {
        
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
    
//MARK: Setup Notify ----------------------------
    
    func setupNotify(isPeripheral : Peripheral) {

        print("write click")
        
        NotificationCenter.default.addObserver(forName: Peripheral.PeripheralCharacteristicValueUpdate,
                                               object: isPeripheral,
                                               queue: nil) { (notification) in
            let charac = notification.userInfo!["characteristic"] as! CBCharacteristic
            if let error = notification.userInfo?["error"] as? SBError {
                // Deal with error
                print("charac error : \(error)")
            }
            
            print("charac : \(charac.value?.hex ?? "")")
            let valueList = charac.value?.hex.components(separatedBy: " ")
            self.detectBLECommand(valueList: valueList!)
            }
        
        isPeripheral.setNotifyValue(toEnabled: true, forCharacWithUUID: "fff4", ofServiceWithUUID: "fff0") { result in
            
            // If there were no errors, you will now receive Notifications when that characteristic value gets updated.
            switch result {
            case .success:
                
                print("notify success")
                break // The write was succesful.
            
            case .failure( _):
                
                print("notify failed")
                break // An error happened while writting the data.
            }
        }
    }
    
    func detectBLECommand(valueList:Array<String>)  {
        
        if valueList.count > 0 {
            
            let command:String = valueList[3] + valueList[4]
        
            print("BT_Manager : Notify command \(command)")
            
            if command == "1001" { // Prev
            
            }
            
            if command == "1002" { // Next
                NotificationCenter.default.post(name: NSNotification.Name("upButton"), object: nil)
            }
            
            if command == "1003" { // Prev
                NotificationCenter.default.post(name: NSNotification.Name("downButton"), object: nil)
            }
            
            if command == "1004" { // Chip ID
  
            }
            
            if command == "1005" { // Wifi status
                let wifiStatus:String = valueList[7]
                
                if wifiStatus == "01" {
                    NotificationCenter.default.post(name: NSNotification.Name("wifiSuccess"), object: nil)
                } else if wifiStatus == "02" {
                    NotificationCenter.default.post(name: NSNotification.Name("wifiFail"), object: nil)
                } else if wifiStatus == "03" {
                    NotificationCenter.default.post(name: NSNotification.Name("wifiFail"), object: nil)
                }
            }
        
            if command == "1006" { // Wifi name

                var myWifiName : String = ""
                var lenght     : UInt64 = 0
                var complete   : Bool   = false
                
                for (index, element) in  valueList.enumerated() {
                    
                    if index == 6 {
                        
                        let _:String    = "0x\(element)"
                        lenght          = UInt64(element, radix:26)! * 2
                        
                        print("BT_Manager : Notify command \(command)")
                    }
                    
                    if index > 6 && index <= lenght {
                        
                        myWifiName.append("\(element)")
                        
                        print("BT_Manager : Notify command \(myWifiName)")
                    }
                    
                    if (myWifiName.length == lenght && lenght != 0 && complete == false) {
                        
                        let str = String(data: myWifiName.hexadecimal!, encoding: .utf8)
                        print("str : \(str ?? "")")
                        
                        complete  = true
                        
                        NotificationCenter.default.post(name: NSNotification.Name("wifiName"), object: nil, userInfo: ["name":str as Any])
                    }
                }
            }
            
            if command == "1007" { //Signal Type KU or C band

            }
            
            if command == "1008" { // For ads not use

            }
            
            if command == "1012" { // STB  Country KH MM
            
            }
        }
    }
    
    func setupDetectTouchRemote(result : String) -> [UInt8] {
        
        switch result {
        case "V_KEY_POWER":
            return [0x84]
        case "V_KEY_FAV":
            return [0x98]
        case "V_KEY_MUTE":
            return [0x94]
        case "V_KEY_ASPECT_MODE":
            return [0xFF]
        case "V_KEY_VIDEO_MODE":
            return [0xFF]
        case "V_KEY_SLEEP":
            return [0x9F]
        case "V_KEY_AUDIO":
            return [0x97]
        case "V_KEY_1":
            return [0x87]
        case "V_KEY_2":
            return [0x86]
        case "V_KEY_3":
            return [0x85]
        case "V_KEY_4":
            return [0x8B]
        case "V_KEY_5":
            return [0x8A]
        case "V_KEY_6":
            return [0x89]
        case "V_KEY_7":
            return [0x8F]
        case "V_KEY_8":
            return [0x8E]
        case "V_KEY_9":
            return [0x8D]
        case "V_KEY_0":
            return [0x92]
        case "V_KEY_SUBT":
            return [0xFF]
        case "V_KEY_TTX":
            return [0xFF]
        case "V_KEY_PAGE_UP":
            return [0xFF]
        case "V_KEY_PAGE_DOWN":
            return [0xFF]
        case "V_KEY_RECALL":
            return [0xFF]
        case "V_KEY_TVRADIO":
            return [0x9B]
        case "V_KEY_MENU":
            return [0x93]
        case "V_KEY_CANCEL":
            return [0x96]
        case "V_KEY_UP":
            return [0x81]
        case "V_KEY_DOWN":
            return [0x88]
        case "V_KEY_LEFT":
            return [0x90]
        case "V_KEY_RIGHT":
            return [0x82]
        case "V_KEY_OK":
            return [0x99]
        case "V_KEY_EPG":
            return [0xCD]
        case "V_KEY_INFO":
            return [0x9C]
        case "V_KEY_SAT":
            return [0x9A]
        case "V_KEY_RED":
            return [0xC9]
        case "V_KEY_GREEN":
            return [0xC4]
        case "V_KEY_YELLOW":
            return [0xC6]
        case "V_KEY_BLUE":
            return [0xCD]
        case "V_KEY_FIND":
            return [0xFF]
        case "V_KEY_ZOOM":
            return [0xFF]
        case "V_KEY_VUP":
            return [0xFF]
        case "V_KEY_VDOWN":
            return [0xFF]
        case "V_KEY_BACK":
            return [0xFF]
        case "V_KEY_FORW":
            return [0xFF]
        case "V_KEY_PAUSE":
            return [0xFF]
        case "V_KEY_STOP":
            return [0xFF]
        case "V_KEY_CHDOWN":
            return [0xFF]
        case "V_KEY_CHUP":
            return [0xFF]
        case "V_KEY_PLAY":
            return [0xFF]
        case "V_KEY_REC":
            return [0xFF]
        case "V_KEY_PREV":
            return [0xFF]
        case "V_KEY_NEXT":
            return [0xFF]
        case "V_KEY_REPEAT":
            return [0xFF]
        case "V_KEY_LIST":
            return [0xFF]
        case "V_KEY_GOTO":
            return [0xFF]
        case "V_KEY_CTRL2":
            return [0xFF]
        case "V_KEY_CTRL3":
            return [0x80]
        case "Youtube":
            return [0x91]
        default:
            
            print("None button remote ----------------")
            
            return [0x99]
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
    
    var hex: String {
        var hexString = ""
        for byte in self {
            hexString += String(format: "%02X ", byte)
        }
        return hexString
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

extension String {
    
    /// Create `Data` from hexadecimal string representation
    ///
    /// This creates a `Data` object from hex string. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.
    
    var hexadecimal: Data? {
        var data = Data(capacity: self.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
    
}

//Count Character ----------

extension String {
    var length: Int { return self.count }
}
