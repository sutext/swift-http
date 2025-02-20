//
//  Monitor.swift
//  
//
//  Created by supertext on 2023/4/28.
//

import Foundation
import Network

public class Monitor{
    private static let StatusChanged:Notification.Name = .init("http.monitor.status.changed")
    private static let monitor:NWPathMonitor = NWPathMonitor()
    private static let notify:NotificationCenter = .init()
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
            self.updateNetworkType()
#endif
        }
    }
    public class func addStatus(observer:Any,selector:Selector){
        self.notify.addObserver(observer, selector: selector, name: StatusChanged, object: nil)
    }
    public class func removeStatus(observer:Any){
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
            self.monitor.start(queue: .global())
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
    private static let NetTypeChanged: Notification.Name = .init("http.monitor.type.changed")
    // Property to hold the current network type
    public private(set) static var networkType: ConnectionType = .noConnection {
        didSet {
            DispatchQueue.main.async {
                notify.post(name: NetTypeChanged, object: self, userInfo: nil)
            }
        }
    }
    public class func addTypeChange(observer:Any,selector:Selector){
        self.notify.addObserver(observer, selector: selector, name: NetTypeChanged, object: nil)
    }
    public class func removeTypeChange(observer:Any){
        self.notify.removeObserver(observer, name: NetTypeChanged, object: nil)
    }
    private static let networkInfo = CTTelephonyNetworkInfo()
    // Method to update the current network type
    private class func updateNetworkType() {
        guard status == .satisfied else {
            networkType = .noConnection
            return
        }

        if nwpath.usesInterfaceType(.wifi) {
            networkType = .wifi
        } else if nwpath.usesInterfaceType(.cellular) {
            // Using serviceCurrentRadioAccessTechnology to get network technology
            let radioAccessTechnology = networkInfo.serviceCurrentRadioAccessTechnology?.values.first ?? "Unknown"

            // Define the base network type mapping (applicable to all versions)
            var networkTypeMapping: [String: ConnectionType] = [
                CTRadioAccessTechnologyLTE: .cellular4G,
                CTRadioAccessTechnologyWCDMA: .cellular3G,
                CTRadioAccessTechnologyHSDPA: .cellular3G,
                CTRadioAccessTechnologyHSUPA: .cellular3G,
                CTRadioAccessTechnologyGPRS: .cellular2G,
                CTRadioAccessTechnologyEdge: .cellular2G
            ]

            // Add 5G checks for iOS 14.1 and above
            if #available(iOS 14.1, *) {
                networkTypeMapping[CTRadioAccessTechnologyNRNSA] = .cellular5G
                networkTypeMapping[CTRadioAccessTechnologyNR] = .cellular5G
            }

            networkType = networkTypeMapping[radioAccessTechnology] ?? .unknown
        } else {
            networkType = .unknown
        }
    }
    public static func getWiFiName() -> String? {
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
    // Define network type enumeration
    public enum ConnectionType: String {
        case wifi = "WiFi"                 // Wi-Fi connection
        case cellular5G = "5G"             // 5G cellular connection
        case cellular4G = "4G"             // 4G cellular connection
        case cellular3G = "3G"             // 3G cellular connection
        case cellular2G = "2G"             // 2G cellular connection
        case unknown = "Unknown"           // Unknown connection type
        case noConnection = "No Connection" // No network connection
        
        public var isWifi: Bool {
            return self == .wifi
        }
        
        public var isCellular: Bool {
            return [.cellular5G, .cellular4G, .cellular3G, .cellular2G].contains(self)
        }
        
        public var isUnknown: Bool {
            return self == .unknown
        }
        
        public var isNoConnect: Bool {
            return self == .noConnection
        }
    }
}
#endif
