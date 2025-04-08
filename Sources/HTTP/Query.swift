//
//  Query.swift
//  swift-http
//
//  Created by supertext on 2025/4/8.
//

import Foundation

/// Creates a url-encoded query string to be set as or appended to any existing URL query string or set as the HTTP
/// body of the URL request. Whether the query string is set or appended to any existing URL query string or set as
/// the HTTP body depends on the destination of the encoding.
///
/// The `Content-Type` HTTP header field of an encoded request with HTTP body is set to
/// `application/x-www-form-urlencoded; charset=utf-8`.
///
/// There is no published specification for how to encode collection types. By default the convention of appending
/// `[]` to the key for array values (`foo[]=1&foo[]=2`), and appending the key surrounded by square brackets for
/// nested dictionary values (`foo[bar]=baz`) is used. Optionally, `arrayBrackets` can be used to omit the
/// square brackets appended to array keys.
///
/// `boolNumeric` can be used to configure how boolean values are encoded. The default behavior is to encode
/// `true` as 1 and `false` as 0.
///
public struct URLQuery:Sendable{
    private var values:[String:AnyValue]
    private let boolNumeric:Bool
    private let arrayBrackets:Bool
    /// Creates an instance using the specified parameters.
    ///
    /// - Parameters:
    ///   - values: key-vallue dictionary
    ///   - arrayBrackets: if `true` an empty set of square brackets is appended to the key for every value
    ///   - boolNumeric:  if `true` encode `true` as `1` and `false` as `0` otherwise encode `true` and `false` as string literals.
    public init(_ values:[String:AnyValue] = [:],arrayBrackets: Bool = true, boolNumeric: Bool = true) {
        self.values = values
        self.arrayBrackets = arrayBrackets
        self.boolNumeric = boolNumeric
    }
    public init(_ values:[String:Any],arrayBrackets: Bool = true, boolNumeric: Bool = true) {
        let values = AnyValue(values).objectValue
        self.init(values,arrayBrackets: arrayBrackets,boolNumeric: boolNumeric)
    }
    public subscript(key:String)->AnyValue?{
        get { values[key] }
        set { values[key] = newValue}
    }
    /// Get the percent-escaped, URL encoded query string from the given key-value paiirs.
    public func encode()->String?{
        if values.isEmpty{ return nil }
        var components: [(String, String)] = []
        for key in values.keys.sorted(by: <) {
            let value = values[key]!
            components += encode(key, value: value)
        }
        if components.isEmpty { return nil }
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
    /// Creates a percent-escaped, URL encoded query string components from the given key-value pair recursively.
    ///
    /// - Parameters
    ///   - key:   Key of the query component.
    ///   - value: Value of the query component.
    ///
    /// - Returns: The percent-escaped, URL encoded query string components.
    private func encode(_ key:String ,value:AnyValue) -> [(String, String)] {
        var components: [(String, String)] = []
        switch value {
        case .bool(let bool):
            components.append((escape(key), escape(encode(bool: bool))))
        case .string(let string):
            components.append((escape(key), escape("\(string)")))
        case .number(let number):
            components.append((escape(key), escape("\(number)")))
        case .object(let object) :
            for (nestedKey, value) in object {
                if case .null = value{ continue }
                components += encode("\(key)[\(nestedKey)]", value: value)
            }
        case .array(let array):
            for value in array {
                if case .null = value{ continue }
                components += encode(encode(array: key), value: value)
            }
        default:
            break
        }
        return components
    }
    private func encode(array key:String)->String{
        if arrayBrackets{
            return "\(key)[]"
        }
        return key
    }
    private func encode(bool value:Bool)->String{
        if boolNumeric{
            return value ? "1" : "0"
        }
        return value ? "true" : "false"
    }
    /// Creates a percent-escaped string following RFC 3986 for a query string key or value.
    ///
    /// - Parameter string: `String` to be percent-escaped.
    ///
    /// - Returns:          The percent-escaped `String`.
    private func escape(_ string: String) -> String {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        let encodableDelimiters = CharacterSet(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        let set = CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
        return string.addingPercentEncoding(withAllowedCharacters: set) ?? string
    }
}
