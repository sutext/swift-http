//
//  Monitor.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Network
import Foundation

public class Network{
    private static let monitor:NWPathMonitor = NWPathMonitor()
    private static let notify:NotificationCenter = .init()
    private static let queue:DispatchQueue = .init(label: "swift.http.monitor.queue")
    /// global network status
    public private(set) static var status:NWPath.Status = .unsatisfied{
        didSet{
            if status == oldValue{
                return
            }
            DispatchQueue.main.async {
                notify.post(name: ObserverType.status.notifyName, object: self)
            }
        }
    }
    public private(set) static var path:NWPath = monitor.currentPath{
        didSet{
            if path == oldValue{
                return
            }
            DispatchQueue.main.async {
                notify.post(name: ObserverType.path.notifyName, object: self)
            }
#if os(iOS)
            self.updateInterface(path)
#endif
        }
    }
    public class func addObserver(_ observer:Any,for type:ObserverType,selector:Selector){
        self.notify.addObserver(observer, selector: selector, name: type.notifyName, object: nil)
    }
    public class func removeObserver(_ observer:Any,for type:ObserverType){
        self.notify.removeObserver(observer, name: type.notifyName, object: nil)
    }
    public class func startMonitor() {
        if self.monitor.pathUpdateHandler == nil{
            self.monitor.pathUpdateHandler = {
                self.path = $0
                self.status = $0.status
            }
        }
        if self.monitor.queue == nil{
            self.monitor.start(queue: queue)
        }
    }
    public class func stopMonitor() {
        self.monitor.cancel()
    }
    public static var isReachable:Bool {
        if case .satisfied = self.status{
            return true
        }
        return false
    }
    public static var isExpensive:Bool {
        return self.path.isExpensive
    }
    @available(iOS 13.0,*)
    public static var isConstrained:Bool {
        return self.path.isConstrained
    }
}
extension Network{
    public enum ObserverType:String,CaseIterable{
        case path = "swift.http.observer.path"
        case status = "swift.http.observer.status"
        case interface = "swift.http.observer.interface"
        var notifyName:Notification.Name{ .init(rawValue: rawValue) }
    }
}
#if os(iOS)
import CoreTelephony
import SystemConfiguration.CaptiveNetwork
extension Network {
    // Property to hold the current network type
    public private(set) static var interface: Interface = .none {
        didSet {
            if interface == oldValue { return }
            DispatchQueue.main.async {
                notify.post(name: ObserverType.interface.notifyName, object: self)
            }
        }
    }
    // Method to update the current network interface
    private class func updateInterface(_ path:NWPath) {
        guard path.status == .satisfied else {
            interface = .none
            return
        }
        if path.usesInterfaceType(.wifi) {
            interface = .wifi(name:getWifiName() ?? "Unknown")
        } else if path.usesInterfaceType(.cellular) {
            if let g = getCellularGeneration(){
                interface = .cellular(g)
            }else{
                interface = .unknown
            }
        } else if path.usesInterfaceType(.wiredEthernet) {
            interface = .wired
        }else{
            interface = .unknown
        }
    }
    static func getCellularGeneration() -> Generation? {
        // Define the base network type mapping (applicable to all versions)
        var mapping: [String: Generation] = [
            CTRadioAccessTechnologyLTE: .g4,
            CTRadioAccessTechnologyWCDMA: .g3,
            CTRadioAccessTechnologyHSDPA: .g3,
            CTRadioAccessTechnologyHSUPA: .g3,
            CTRadioAccessTechnologyCDMA1x: .g3,
            CTRadioAccessTechnologyCDMAEVDORev0:.g3,
            CTRadioAccessTechnologyCDMAEVDORevA:.g3,
            CTRadioAccessTechnologyCDMAEVDORevB: .g3,
            CTRadioAccessTechnologyeHRPD:.g3,
            CTRadioAccessTechnologyGPRS: .gprs,
            CTRadioAccessTechnologyEdge: .g2
        ]
        if #available(iOS 14.1, *) {
            mapping[CTRadioAccessTechnologyNRNSA] = .g5
            mapping[CTRadioAccessTechnologyNR] = .g5
        }
        // Using serviceCurrentRadioAccessTechnology to get network technology
        if let key = CTTelephonyNetworkInfo().serviceCurrentRadioAccessTechnology?.values.first,
           let cell = mapping[key]{
            return cell
        }
        return nil
    }
    static func getWifiName() -> String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else {
            return nil
        }
        for interface in interfaces {
            if let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: AnyObject],
               let ssid = info[kCNNetworkInfoKeySSID as String] as? String {
                return ssid
            }
        }
        return nil
    }
}

extension Network {
    // Define network interface enumeration
    public enum Interface : CustomStringConvertible,Hashable{
        case none
        case wifi(name:String)     // Wi-Fi connection
        case wired                  // Wired Ethernet
        case unknown                // Unknown connection type
        case cellular(Generation)     //cellular connection
        public var isWifi: Bool {
            if case .wifi = self {
                return true
            }
            return false
        }
        public var isCellular: Bool {
            if case .cellular = self {
                return true
            }
            return false
        }
        public var isUnknown: Bool {
            if case .unknown = self {
                return true
            }
            return false
        }
        public var isNone: Bool {
            if case .none = self {
                return true
            }
            return false
        }
        public var description: String{
            switch self {
            case .none:
                return "No Connection"
            case .wifi(let name):
                return "Wi-Fi(\(name))"
            case .wired:
                return "Wired Ethernet"
            case .unknown:
                return "Unknown"
            case .cellular(let cellular):
                return cellular.rawValue
            }
        }
    }
    public enum Generation:String,Hashable{
        case g2 = "2G"
        case g3 = "3G"
        case g4 = "4G"
        case g5 = "5G"
        case gprs = "GPRS"
    }
}
#endif
