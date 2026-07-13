import Foundation

struct JSONSchemaValidationError: Error, Equatable {
    let path: String
    let message: String
}

enum JSONSchemaTestValidator {
    static func validate(instance: Any, schema: [String: Any]) throws {
        try validate(instance: instance, schema: schema, root: schema, path: "$")
    }

    private static func validate(
        instance: Any,
        schema: [String: Any],
        root: [String: Any],
        path: String
    ) throws {
        if let reference = schema["$ref"] as? String {
            let name = try referencedDefinitionName(reference, path: path)
            let definitions = try require(root["$defs"] as? [String: Any], path: path, "Missing schema definitions")
            let resolved = try require(definitions[name] as? [String: Any], path: path, "Unknown schema reference")
            try validate(instance: instance, schema: resolved, root: root, path: path)
            return
        }

        if let constant = schema["const"], !jsonValuesEqual(instance, constant) {
            throw JSONSchemaValidationError(path: path, message: "Value does not match const")
        }

        if let allowedTypes = allowedTypes(in: schema), !allowedTypes.contains(where: { matches(instance, type: $0) }) {
            throw JSONSchemaValidationError(path: path, message: "Unexpected JSON type")
        }

        if let minimum = schema["minimum"] as? NSNumber,
           let number = instance as? NSNumber,
           number.doubleValue < minimum.doubleValue {
            throw JSONSchemaValidationError(path: path, message: "Number is below minimum")
        }

        if let maximum = schema["maximum"] as? NSNumber,
           let number = instance as? NSNumber,
           number.doubleValue > maximum.doubleValue {
            throw JSONSchemaValidationError(path: path, message: "Number is above maximum")
        }

        if schema["format"] as? String == "date-time", let value = instance as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard formatter.date(from: value) != nil else {
                throw JSONSchemaValidationError(path: path, message: "Invalid date-time")
            }
        }

        if let object = instance as? [String: Any] {
            let properties = schema["properties"] as? [String: Any] ?? [:]
            for key in schema["required"] as? [String] ?? [] where object[key] == nil {
                throw JSONSchemaValidationError(path: path, message: "Missing required property \(key)")
            }
            if schema["additionalProperties"] as? Bool == false {
                let extras = Set(object.keys).subtracting(properties.keys)
                guard extras.isEmpty else {
                    throw JSONSchemaValidationError(path: path, message: "Unknown properties \(extras.sorted())")
                }
            }
            for (key, value) in object {
                guard let propertySchema = properties[key] as? [String: Any] else { continue }
                try validate(instance: value, schema: propertySchema, root: root, path: "\(path).\(key)")
            }
        }

        if let array = instance as? [Any] {
            if let minItems = schema["minItems"] as? Int, array.count < minItems {
                throw JSONSchemaValidationError(path: path, message: "Array has fewer than \(minItems) items")
            }
            if let maxItems = schema["maxItems"] as? Int, array.count > maxItems {
                throw JSONSchemaValidationError(path: path, message: "Array has more than \(maxItems) items")
            }
            if let itemSchema = schema["items"] as? [String: Any] {
                for (index, value) in array.enumerated() {
                    try validate(instance: value, schema: itemSchema, root: root, path: "\(path)[\(index)]")
                }
            }
        }

        if let subschemas = schema["allOf"] as? [[String: Any]] {
            for (index, subschema) in subschemas.enumerated() {
                try validateContainsIfPresent(instance: instance, schema: subschema, root: root, path: "\(path)/allOf[\(index)]")
                let remaining = subschema.filter { !["contains", "minContains", "maxContains"].contains($0.key) }
                if !remaining.isEmpty {
                    try validate(instance: instance, schema: remaining, root: root, path: "\(path)/allOf[\(index)]")
                }
            }
        }

        try validateContainsIfPresent(instance: instance, schema: schema, root: root, path: path)
    }

    private static func validateContainsIfPresent(
        instance: Any,
        schema: [String: Any],
        root: [String: Any],
        path: String
    ) throws {
        guard let containsSchema = schema["contains"] as? [String: Any] else { return }
        guard let array = instance as? [Any] else { return }
        var matchCount = 0
        for value in array {
            do {
                try validate(instance: value, schema: containsSchema, root: root, path: path)
                matchCount += 1
            } catch is JSONSchemaValidationError {
                continue
            }
        }
        let minContains = schema["minContains"] as? Int ?? 1
        if matchCount < minContains {
            throw JSONSchemaValidationError(path: path, message: "Array contains fewer than \(minContains) matching items")
        }
        if let maxContains = schema["maxContains"] as? Int, matchCount > maxContains {
            throw JSONSchemaValidationError(path: path, message: "Array contains more than \(maxContains) matching items")
        }
    }

    private static func allowedTypes(in schema: [String: Any]) -> [String]? {
        if let type = schema["type"] as? String { return [type] }
        return schema["type"] as? [String]
    }

    private static func matches(_ value: Any, type: String) -> Bool {
        switch type {
        case "null": return value is NSNull
        case "object": return value is [String: Any]
        case "array": return value is [Any]
        case "string": return value is String
        case "boolean": return isJSONBoolean(value)
        case "integer":
            guard !isJSONBoolean(value), let number = value as? NSNumber else { return false }
            return number.doubleValue.rounded() == number.doubleValue
        case "number": return !isJSONBoolean(value) && value is NSNumber
        default: return false
        }
    }

    private static func isJSONBoolean(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func jsonValuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        (lhs as? NSObject)?.isEqual(rhs) == true
    }

    private static func referencedDefinitionName(_ reference: String, path: String) throws -> String {
        let prefix = "#/$defs/"
        guard reference.hasPrefix(prefix), reference.count > prefix.count else {
            throw JSONSchemaValidationError(path: path, message: "Unsupported schema reference")
        }
        return String(reference.dropFirst(prefix.count))
    }

    private static func require<T>(_ value: T?, path: String, _ message: String) throws -> T {
        guard let value else { throw JSONSchemaValidationError(path: path, message: message) }
        return value
    }
}
