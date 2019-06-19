// MIT License © Sindre Sorhus
import Foundation

public final class Defaults {
	public class Keys {
		public typealias Key = Defaults.Key
		public typealias OptionalKey = Defaults.OptionalKey
		public typealias SecureKey = Defaults.SecureKey
		public typealias OptionalSecureKey = Defaults.OptionalSecureKey

		fileprivate init() {}
	}

	public final class Key<T: Codable>: Keys {
		public let name: String
		public let defaultValue: T
		public let suite: UserDefaults

		public init(_ key: String, default defaultValue: T, suite: UserDefaults = .standard) {
			self.name = key
			self.defaultValue = defaultValue
			self.suite = suite

			super.init()

			// Sets the default value in the actual UserDefaults, so it can be used in other contexts, like binding.
			if UserDefaults.isNativelySupportedType(T.self) {
				suite.register(defaults: [key: defaultValue])
			} else if let value = suite._encode(defaultValue) {
				suite.register(defaults: [key: value])
			}
		}
	}
	
	public final class SecureKey<T: NSSecureCoding>: Keys {
		public let name: String
		public let defaultValue: T
		public let suite: UserDefaults
		
		public init(_ key: String, default defaultValue: T, suite: UserDefaults = .standard) {
			self.name = key
			self.defaultValue = defaultValue
			self.suite = suite
			
			super.init()
			
			// Sets the default value in the actual UserDefaults, so it can be used in other contexts, like binding.
			if let value = suite._encode(defaultValue) {
				suite.register(defaults: [key: value])
			}
		}
	}
	
	public final class OptionalKey<T: Codable>: Keys {
		public let name: String
		public let suite: UserDefaults

		public init(_ key: String, suite: UserDefaults = .standard) {
			self.name = key
			self.suite = suite
		}
	}
	
	public final class OptionalSecureKey<T: NSSecureCoding>: Keys {
		public let name: String
		public let suite: UserDefaults
		
		public init(_ key: String, suite: UserDefaults = .standard) {
			self.name = key
			self.suite = suite
		}
	}

	fileprivate init() {}

	public subscript<T: Codable>(key: Defaults.Key<T>) -> T {
		get {
			return key.suite[key]
		}
		set {
			key.suite[key] = newValue
		}
	}

	public subscript<T: Codable>(key: Defaults.OptionalKey<T>) -> T? {
		get {
			return key.suite[key]
		}
		set {
			key.suite[key] = newValue
		}
	}
	
	public subscript<T: NSSecureCoding>(key: Defaults.SecureKey<T>) -> T {
		get {
			return key.suite[key]
		}
		set {
			key.suite[key] = newValue
		}
	}
	
	public subscript<T: NSSecureCoding>(key: Defaults.OptionalSecureKey<T>) -> T? {
		get {
			return key.suite[key]
		}
		set {
			key.suite[key] = newValue
		}
	}

	public func clear(suite: UserDefaults = .standard) {
		for key in suite.dictionaryRepresentation().keys {
			suite.removeObject(forKey: key)
		}
	}
}

// Has to be `defaults` lowercase until Swift supports static subscripts…
public let defaults = Defaults()

extension UserDefaults {
	private func _get<T: Codable>(_ key: String) -> T? {
		if UserDefaults.isNativelySupportedType(T.self) {
			return object(forKey: key) as? T
		}

		guard
			let text = string(forKey: key),
			let data = "[\(text)]".data(using: .utf8)
		else {
			return nil
		}

		do {
			return (try JSONDecoder().decode([T].self, from: data)).first
		} catch {
			print(error)
		}

		return nil
	}
	
	private func _set<T: Codable>(_ key: String, to value: T) {
		if UserDefaults.isNativelySupportedType(T.self) {
			set(value, forKey: key)
			return
		}
		
		set(_encode(value), forKey: key)
	}

	fileprivate func _encode<T: Codable>(_ value: T) -> String? {
		do {
			// Some codable values like URL and enum are encoded as a top-level
			// string which JSON can't handle, so we need to wrap it in an array
			// We need this: https://forums.swift.org/t/allowing-top-level-fragments-in-jsondecoder/11750
			let data = try JSONEncoder().encode([value])
			return String(String(data: data, encoding: .utf8)!.dropFirst().dropLast())
		} catch {
			print(error)
			return nil
		}
	}
	
	private func _get<T: NSSecureCoding>(_ key: String) -> T? {
		guard
			let data = data(forKey: key)
			else {
				return nil
		}
		
		do {
			return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? T
		} catch {
			print(error)
		}
		
		return nil
	}
	
	private func _set<T: NSSecureCoding>(_ key: String, to value: T) {
		set(_encode(value), forKey: key)
	}

	fileprivate func _encode<T: NSSecureCoding>(_ value: T) -> Data? {
		do {
			let data: Data
			if #available(iOSApplicationExtension 11.0, *) {
				data = try NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
			} else {
				data = NSKeyedArchiver.archivedData(withRootObject: value)
			}
			return data
		} catch {
			print(error)
			return nil
		}
	}

	public subscript<T: Codable>(key: Defaults.Key<T>) -> T {
		get {
			return _get(key.name) ?? key.defaultValue
		}
		set {
			_set(key.name, to: newValue)
		}
	}

	public subscript<T: Codable>(key: Defaults.OptionalKey<T>) -> T? {
		get {
			return _get(key.name)
		}
		set {
			guard let value = newValue else {
				set(nil, forKey: key.name)
				return
			}

			_set(key.name, to: value)
		}
	}
	
	public subscript<T: NSSecureCoding>(key: Defaults.SecureKey<T>) -> T {
		get {
			return _get(key.name) ?? key.defaultValue
		}
		set {
			_set(key.name, to: newValue)
		}
	}
	
	public subscript<T: NSSecureCoding>(key: Defaults.OptionalSecureKey<T>) -> T? {
		get {
			return _get(key.name)
		}
		set {
			guard let value = newValue else {
				set(nil, forKey: key.name)
				return
			}
			
			_set(key.name, to: value)
		}
	}

	fileprivate static func isNativelySupportedType<T>(_ type: T.Type) -> Bool {
		switch type {
		case is Bool.Type,
			 is String.Type,
			 is Int.Type,
			 is Double.Type,
			 is Float.Type,
			 is Date.Type,
			 is Data.Type:
			return true
		default:
			return false
		}
	}
}
