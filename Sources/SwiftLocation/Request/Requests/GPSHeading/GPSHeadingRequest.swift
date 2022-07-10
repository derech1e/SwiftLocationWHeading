//
//  File.swift
//  
//
//  Created by Thomas on 10.07.22.
//

import Foundation
import CoreLocation

public class GPSHeadingRequest: RequestProtocol, Codable {
    
    public typealias ProducedData = CLHeading
    
    /// Unique identifier of the request.
    public var uuid: Identifier = UUID().uuidString
    
    /// Readable name.
    public var name: String?
    
    /// `true` if request is enabled.
    public var isEnabled: Bool = true

    /// Options for heading
    public var options: GPSHeadingOptions

    /// Registered callbacks which receive events.
    public var subscriptions = [RequestDataCallback<DataCallback>]()
    
    /// Number of valid data received.
    public var countReceivedData = 0
    
    /// Last valid received heading from underlying service.
    /// NOTE: Until the first valid result value is `nil.`
    public private(set) var lastHeading: CLHeading?

    /// Last received value from underlying service.
    /// It may also an error, if it's a value its the same of `lastHeading`.
    public var lastReceivedValue: (Result<CLHeading, LocationError>)?

    /// This is the default policy which manage the auto-cancel of a request from queue.
    /// The default implementation different based upon the type of subscription:
    /// - if subscription is `continous` no auto-cancel settings, no evitionPolicy is set and you must remove the request manually.
    /// - if subscription is `single` it will be removed when an error occours (which is not `discardedData`) or first valid result received.
    public var evictionPolicy: Set<RequestEvictionPolicy> {
        set {
            guard options.subscription == .single else {
                _evictionPolicy = newValue // just pass the value.
                return
            }
            // NOTE: For single subscription we must ignore each custom eviction based upon the number of data received
            // Single subscriptions ends at the first valid result, always.
            _evictionPolicy = newValue.filter({ !$0.isReceiveDataEviction })
            _evictionPolicy.insert(.onReceiveData(count: 1))
        }
        get {
            return _evictionPolicy
        }
    }
        
    // MARK: - Private Properties
    
    /// See `evictionPolicy`.
    private var _evictionPolicy = Set<RequestEvictionPolicy>()
    
    /// Timeout timer.
    private var timeoutTimer: Timer?
    
    // MARK: - Codable
        
    enum CodingKeys: String, CodingKey {
        case uuid, isEnabled, options, lastReceivedValue, timeoutTimer, name
    }
    
    // Encodable protocol
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(options, forKey: .options)
        try container.encodeIfPresent(name, forKey: .name)
    }
    
    // Decodable protocol
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(String.self, forKey: .uuid)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.options = try container.decode(GPSHeadingOptions.self, forKey: .options)
        self.options.request = self
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
    }
     
    // MARK: - Initialization
    
    /// Initialize.
    /// - Parameter headingOptions: custom options to use.
    internal init(_ headingOptions: GPSHeadingOptions? = nil) {
        self.options = headingOptions ?? GPSHeadingOptions()
        self.options.request = self
        
        if options.subscription == .single {
            self.evictionPolicy = [.onError, .onReceiveData(count: 1)]
        }
    }
    
    public static func == (lhs: GPSHeadingRequest, rhs: GPSHeadingRequest) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
    
    // MARK: - Public Functions

    public func validateData(_ data: ProducedData) -> DataDiscardReason? {
        guard isEnabled else {
            return .requestNotEnabled // request is not enabled so we'll discard data.
        }
        
        guard data.horizontalAccuracy <= options.accuracy.value else {
            return .notMinAccuracy // accuracy level is below the minimum set
        }
        
        if let previousHeading = lastHeading {
            // We have already received a previous valid heading so we'll
            // also check for distance and interval if required and eventually dispatch value.
            if options.headingFilter > kCLDistanceFilterNone,
               previousHeading.distance(from: data) < options.headingFilter {
                return .notMinDistance // minimum distance since last heading is not respected.
            }
            
            if let minInterval = options.minTimeInterval,
               Date().timeIntervalSince(previousHeading.timestamp) <= minInterval {
                return .notMinInterval // minimum time interval since last heading is not respected.
            }
        } else {
            // This is the first time we receive a heading inside this request.
            // We have validated the accuracy so we can store it. Subsequent
            // call of the validateData method will land in the if above and also
            // check the minDistance and minInterval.
            lastHeading = data
        }
        
        // Store previous value because it was validated.
        lastHeading = data
        
        return nil
    }
    
    public func startTimeoutIfNeeded() {
        guard let timeout = options.timeout, // has valid timeout settings
              timeout.canFireTimer, // can fire the timer (timeout is immediate or delayed with auth ok)
              timeoutTimer == nil else { // timer never started yet for this request
            return
        }
        
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout.interval, repeats: false, block: { [weak self] timer in
            timer.invalidate()
            self?.receiveData(.failure(.timeout))
        })
    }
    
    public var description: String {
        JSONStringify([
            "uuid" : uuid,
            "name": name ?? "",
            "enabled": isEnabled,
            "options": options.description,
            "subscriptions": subscriptions.count,
            "lastValue": lastReceivedValue?.description ?? "",
            "timeout": timeoutTimer?.description ?? ""
        ])
    }
    
}

// MARK: - Result<CLHeading,LocatorErrors>

public extension Result where Success == CLHeading, Failure == LocationError {
    
    var description: String {
        switch self {
        case .failure(let error):
            return "Failure \(error.localizedDescription)"
        case .success(let heading):
            return "Success \(heading.description)"
        }
    }
    
}
    
}
