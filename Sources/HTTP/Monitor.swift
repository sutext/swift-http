//
//  Monitor.swift
//
//
//  Created by supertext on 2023/4/28.
//

import Network


class Monitor{
    private static let StatusChanged:Notification.Name = .init("swifthttp.network.status.changed")
    private static let monitor:NWPathMonitor = NWPathMonitor()
    private static let notify:NotificationCenter = .init()
    private static let queue:DispatchQueue = .init(label: "swifthttp.monitor.queue")
    /// global network status
    public private(set) static var status:NWPath.Status = .unsatisfied{
        didSet{
            if status == oldValue{
                return
            }
            DispatchQueue.main.async {
                notify.post(name: StatusChanged, object: self,userInfo: ["status":status])
            }
        }
    }
    public private(set) static var nwpath:NWPath = monitor.currentPath{
        didSet{
            if nwpath == oldValue{
                return
            }
#if os(iOS)
            self.updateInterface(nwpath)
#endif
        }
    }
    public class func addStatusObserver(_ observer:Any,selector:Selector){
        self.notify.addObserver(observer, selector: selector, name: StatusChanged, object: nil)
    }
    public class func removeStatusObserver(_ observer:Any){
        self.notify.removeObserver(observer, name: StatusChanged, object: nil)
    }
    public class func startMonitor() {
        if self.monitor.pathUpdateHandler == nil{
            self.monitor.pathUpdateHandler = {
                self.nwpath = $0
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
        return self.nwpath.isExpensive
    }
    @available(iOS 13.0,*)
    public static var isConstrained:Bool {
        return self.nwpath.isConstrained
    }
}

#if os(iOS)
import CoreTelephony
import SystemConfiguration.CaptiveNetwork
extension Monitor {
    private static let InterfaceChanged: Notification.Name = .init("swifthttp.network.mode.changed")
    // Property to hold the current network type
    public private(set) static var interface: Interface = .none {
        didSet {
            DispatchQueue.main.async {
                notify.post(name: InterfaceChanged, object: self, userInfo: nil)
            }
        }
    }
    public class func addModeObserver(_ observer:Any,selector:Selector){
        self.notify.addObserver(observer, selector: selector, name: InterfaceChanged, object: nil)
    }
    public class func removeModeObserver(_ observer:Any){
        self.notify.removeObserver(observer, name: InterfaceChanged, object: nil)
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

extension Monitor {
    // Define network interface enumeration
    public enum Interface : CustomStringConvertible{
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
    public enum Generation:String{
        case g2 = "2G"
        case g3 = "3G"
        case g4 = "4G"
        case g5 = "5G"
        case gprs = "GPRS"
    }
}
#endif
