import Foundation

public enum AnyCodableValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let val = try? container.decode(Int.self) {
            self = .int(val)
        } else if let val = try? container.decode(Double.self) {
            self = .double(val)
        } else if let val = try? container.decode(Bool.self) {
            self = .bool(val)
        } else if let val = try? container.decode(String.self) {
            self = .string(val)
        } else if let val = try? container.decode([String].self) {
            self = .stringArray(val)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported AnyCodable value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .stringArray(let arr): try container.encode(arr)
        case .null: try container.encodeNil()
        }
    }

    public init(_ string: String) {
        self = .string(string)
    }

    public init(_ int: Int) {
        self = .int(int)
    }

    public init(_ double: Double) {
        self = .double(double)
    }

    public init(_ bool: Bool) {
        self = .bool(bool)
    }

    public init(_ array: [String]) {
        self = .stringArray(array)
    }

    public init(_ any: Any) {
        if let s = any as? String { self = .string(s) }
        else if let i = any as? Int { self = .int(i) }
        else if let d = any as? Double { self = .double(d) }
        else if let b = any as? Bool { self = .bool(b) }
        else if let arr = any as? [String] { self = .stringArray(arr) }
        else { self = .string(String(describing: any)) }
    }

    nonisolated public var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d):
            return d.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(d)) : String(d)
        case .bool(let b): return String(b)
        case .stringArray(let arr): return arr.joined(separator: ", ")
        case .null: return nil
        }
    }

    nonisolated public var doubleValue: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i): return Double(i)
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    nonisolated public var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        case .string(let s): return Int(s)
        default: return nil
        }
    }

    nonisolated public var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        case .string(let s): return Bool(s)
        default: return nil
        }
    }

    nonisolated public var stringArrayValue: [String]? {
        switch self {
        case .stringArray(let arr): return arr
        case .string(let s): return [s]
        default: return nil
        }
    }

    nonisolated public var isEmpty: Bool {
        switch self {
        case .null:
            return true
        case .string(let s):
            return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .stringArray(let arr):
            return arr.isEmpty
        case .int, .double, .bool:
            return false
        }
    }
}

public typealias AnyCodable = AnyCodableValue
