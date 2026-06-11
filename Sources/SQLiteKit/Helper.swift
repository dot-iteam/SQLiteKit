//
//  Help.swift
//  SQLiteKit
//
//  Created by Dot iTeam on 2026-06-02.
//

import RegexBuilder
func extractCheckConstraints(from sql: String) -> [String] {
    let regex = Regex {
        "CHECK"
        ZeroOrMore(.whitespace)
        "("
    }.ignoresCase(true)
    var results: [String] = []
    var searchStart = sql.startIndex
    while let match = sql[searchStart..<sql.endIndex].firstMatch(of: regex) {
        let start = match.range.upperBound
        var depth = 1
        var quoteDepth = false
        var quoteChar: Character?
        var current = ""
        var index = start
        if sql.count > 0 {
            while index < sql.endIndex {
                let char = sql[index]
                let isLastOne = sql.index(sql.endIndex, offsetBy: -1) == index
                if char == "'" || char == "\"" || char == "`" {
                    if char == quoteChar {
                        var followedByQuote = false
                        var nextChar: Character?
                        if !isLastOne {
                            nextChar = sql[sql.index(index, offsetBy: 1)]
                            if nextChar == char {
                                followedByQuote = true
                            }
                        }
                        if followedByQuote && !isLastOne {
                            index = sql.index(index, offsetBy: 2)
                            current.append(char)
                            current.append(nextChar!)
                            continue
                        } else {
                            quoteDepth = false
                            quoteChar = nil
                        }
                    } else if !quoteDepth {
                        quoteDepth = true
                        quoteChar = char
                    }
                }
                else if !quoteDepth {
                    if char == "(" {
                        depth += 1
                    } else if char == ")" {
                        depth -= 1
                        if depth == 0 {
                            break
                        }
                    }
                }
                current.append(char)
                index = sql.index(index, offsetBy: 1)
            }
        }
        results.append(current)
        searchStart = index < sql.endIndex ? sql.index(after: index) : sql.endIndex
    }
    return results.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
}

