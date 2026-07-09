import Foundation

public enum TOMLValue: Equatable, Sendable {
    case string(String), int(Int), double(Double), bool(Bool)
}

public enum TOMLError: Error, Equatable {
    case malformedLine(String, line: Int)
}

public enum TOML {
    public static func parse(_ text: String) throws -> [String: [String: TOMLValue]] {
        var out: [String: [String: TOMLValue]] = ["": [:]]
        var section = ""
        var lineNo = 0
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            lineNo += 1
            let line = stripComment(String(raw)).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                out[section, default: [:]] = out[section] ?? [:]
                continue
            }
            guard let eq = line.firstIndex(of: "=") else {
                throw TOMLError.malformedLine(line, line: lineNo)
            }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let rhs = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            out[section, default: [:]][key] = try value(rhs, line: lineNo)
        }
        return out
    }

    private static func stripComment(_ s: String) -> String {
        var inStr = false
        var result = ""
        for ch in s {
            if ch == "\"" { inStr.toggle() }
            if ch == "#" && !inStr { break }
            result.append(ch)
        }
        return result
    }

    private static func value(_ s: String, line: Int) throws -> TOMLValue {
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
            return .string(String(s.dropFirst().dropLast()))
        }
        if s == "true" { return .bool(true) }
        if s == "false" { return .bool(false) }
        if let i = Int(s) { return .int(i) }
        if let d = Double(s) { return .double(d) }
        throw TOMLError.malformedLine(s, line: line)
    }
}
