//
//  File.swift
//  
//
//  Created by Thomas on 10.07.22.
//

import Foundation
import CoreLocation

public class GPSHeadingOptions: CustomStringConvertible, Codable {
    
    /// The timeout policy of the request.
    ///
    /// - `immediate`: timeout countdown starts immediately after the request is added regardless the current authorization level.
    /// - `delayed`: timeout countdown starts only after the required authorization are granted from the user.
    public enum Timeout: CustomStringConvertible, Codable {
        case immediate(TimeInterval)
        case delayed(TimeInterval)
        
        public var interval: TimeInterval {
            switch self {
            case .immediate(let t): return t
            case .delayed(let t):   return t
            }
        }
        
        /// Can start timer.
        /// Timer can be started always if immediate, only if it has authorization when delayed.
        internal var canFireTimer: Bool {
            switch self {
            case .immediate: return true
            case .delayed:   return SwiftLocation.authorizationStatus.isAuthorized
            }
        }
        
        public var description: String {
            switch self {
            case .immediate(let t): return "immediate \(abs(t))s"
            case .delayed(let t):   return "delayed \(abs(t))s"
            }
        }
        
        private var kind: Int {
            switch self {
            case .delayed: return 0
            case .immediate: return 1
            }
        }
        
        // MARK: - Codable
        
        enum CodingKeys: String, CodingKey {
            case kind, interval
        }
        
        // Encodable protocol
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(kind, forKey: .kind)
            try container.encode(interval, forKey: .interval)
        }
        
        // Decodable protocol
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(Int.self, forKey: .kind)
            let interval = try container.decode(TimeInterval.self, forKey: .interval)
            
            switch kind {
            case 0: self = .delayed(interval)
            case 1: self = .immediate(interval)
            default: fatalError("Failed to decode Timeout")
            }
        }
        
    }
    
    public enum Filter: CustomStringConvertible, Codable {
        case degrees(CLLocationDegrees)
        
        public var degrees: CLLocationDegrees {
            switch self {
            case .degrees(let d): return d
            }
        }
        public var description: String {
            switch self {
            case .degrees(let d): return "degrees \(d)°"
            }
        }
        
        // MARK: - Codable
        
        enum CodingKeys: String, CodingKey {
            case degrees
        }
        
        // Encodable protocol
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(degrees, forKey: .degrees)
        }
        
        // Decodable protocol
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let degrees = try container.decode(CLLocationDegrees.self, forKey: .degrees)
            
            self = .degrees(degrees)
        }
    }
    
    public enum DeviceOrientation: CustomStringConvertible, Codable {
        case orientation(CLDeviceOrientation)
        
        public var orientation: CLDeviceOrientation {
            switch self {
            case .orientation(let o): return o
            }
        }
        public var description: String {
            switch self {
            case .orientation(let o): return "orientation \(o)"
            }
        }
        
        // MARK: - Codable
        
        enum CodingKeys: String, CodingKey {
            case orientation
        }
        
        // Encodable protocol
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(orientation, forKey: .orientation)
        }
        
        // Decodable protocol
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let orientation = try container.decode(CLDeviceOrientation.self, forKey: .orientation)
            
            self = .orientation(orientation)
        }
    }
    
    /// Associated request.
    public weak var request: GPSHeadingRequest?
    
    /// Specifies the minimum amount of change in degrees needed for a heading service update.
    public var headingFilter: CLLocationDegrees = kCLHeadingFilterNone
    
    /// Specifies a physical device orientation from which heading calculation should be referenced.
    /// CLDeviceOrientationUnknown, CLDeviceOrientationFaceUp, and CLDeviceOrientationFaceDown are ignored.
    public var headingOrientation: CLDeviceOrientation = .portrait
    
    /// Timeout level, by default is `nil` which means no timeout policy is set and you must end the request manually.
    public var timeout: Timeout?
    
    /// Description of the options.
    public var description: String {
        return "{" + [
            "timeout= \(timeout?.description ?? "none")",
            "headingFilter= \(headingFilter)",
            "headingOrientation= \(headingOrientation)"
        ].joined(separator: ", ") + "}"
    }
    
    
    // MARK: - Initialization
    
    public init() {

    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case timeout, headingFilter, headingOrientation
    }
    
    // Encodable protocol
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(timeout, forKey: .timeout)
        try container.encode(headingFilter, forKey: .headingFilter)
        try container.encode(headingOrientation, forKey: .headingOrientation)
    }
    
    // Decodable protocol
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.timeout = try container.decodeIfPresent(Timeout.self, forKey: .timeout)
        self.headingFilter = try container.decode(CLLocationDegrees.self, forKey: .headingFilter)
        self.headingOrientation = try container.decode(CLDeviceOrientation.self, forKey: .headingOrientation)
    }
}
