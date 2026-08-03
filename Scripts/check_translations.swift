#!/usr/bin/env swift
// Fails if any string in Localization.swift is missing a language.
//
// The catalog uses a dictionary rather than one argument per language, so the
// compiler can no longer catch a forgotten translation. This reads the source
// back and checks every `T([...])` literal instead. Run it before opening a PR.

import Foundation

let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let path = root + "/Sources/MacBroom/Core/Localization.swift"

guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
    print("✗ cannot read \(path)")
    exit(1)
}

// The language list comes from the enum itself, so adding a case here is enough
// to make every existing entry get checked against it.
let languages: [String] = {
    guard
        let start = source.range(of: "enum Language: String, CaseIterable, Identifiable {"),
        let end = source.range(of: "\n}", range: start.upperBound..<source.endIndex)
    else { return [] }
    return source[start.upperBound..<end.lowerBound]
        .split(separator: "\n")
        .compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("case ") else { return nil }
            let name = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            // `case uz` is a language; `case .uz: return "🇺🇿"` inside the switch
            // bodies is not, so only bare identifiers count.
            guard !name.isEmpty, name.allSatisfy({ $0.isLetter }) else { return nil }
            return name
        }
}()

guard !languages.isEmpty else {
    print("✗ could not read the Language enum")
    exit(1)
}

/// Walks `T([` … matching `])`, tracking bracket depth so nested parentheses in
/// string interpolation do not end the literal early.
func literals(in text: String) -> [(line: Int, body: String)] {
    var found: [(Int, String)] = []
    let characters = Array(text)
    var index = 0
    var line = 1

    while index < characters.count {
        if characters[index] == "\n" { line += 1 }
        if index + 3 < characters.count,
            characters[index] == "T", characters[index + 1] == "(", characters[index + 2] == "["
        {
            let startLine = line
            var depth = 0
            var body = ""
            var cursor = index + 1
            var inString = false
            while cursor < characters.count {
                let c = characters[cursor]
                if c == "\n" { line += 1 }
                if c == "\"" && characters[cursor - 1] != "\\" { inString.toggle() }
                if !inString {
                    if c == "(" || c == "[" { depth += 1 }
                    if c == ")" || c == "]" { depth -= 1 }
                }
                body.append(c)
                if depth == 0 { break }
                cursor += 1
            }
            found.append((startLine, body))
            index = cursor + 1
            continue
        }
        index += 1
    }
    return found
}

var problems = 0
let entries = literals(in: source)

for entry in entries {
    let missing = languages.filter { !entry.body.contains(".\($0):") }
    if !missing.isEmpty {
        problems += 1
        let preview = entry.body.prefix(60).replacingOccurrences(of: "\n", with: " ")
        print("✗ Localization.swift:\(entry.line) missing \(missing.joined(separator: ", "))")
        print("   \(preview)…")
    }
}

print("")
print("  languages: \(languages.joined(separator: ", "))")
print("  strings checked: \(entries.count)")
print(problems == 0 ? "  ✓ every string has every language\n" : "  ✗ \(problems) incomplete\n")
exit(problems == 0 ? 0 : 1)
