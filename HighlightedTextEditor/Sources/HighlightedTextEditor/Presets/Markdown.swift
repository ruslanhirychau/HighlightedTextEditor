//
//  Markdown.swift
//
//
//  Created by Kyle Nazario on 5/26/21.
//

import SwiftUI

// MARK: - Regex patterns

private let inlineCodeRegex = try! NSRegularExpression(pattern: "`[^`]*`", options: [])
private let codeBlockRegex = try! NSRegularExpression(
    pattern: "(`){3}((?!\\1).)+\\1{3}",
    options: [.dotMatchesLineSeparators]
)
private let headingRegex = try! NSRegularExpression(pattern: "^#{1,6}\\s.*$", options: [.anchorsMatchLines])
private let headingMarkerRegex = try! NSRegularExpression(pattern: "^#{1,6}\\s", options: [.anchorsMatchLines])
private let boldMarkerRegex = try! NSRegularExpression(pattern: "(\\*{2}|_{2})", options: [])
private let emphasisMarkerRegex = try! NSRegularExpression(pattern: "(?<![\\*_])[\\*_](?![\\*_])", options: [])
private let linkOrImageRegex = try! NSRegularExpression(pattern: "!?\\[([^\\[\\]]*)\\]\\((.*?)\\)", options: [])
private let linkOrImageTagRegex = try! NSRegularExpression(pattern: "!?\\[([^\\[\\]]*)\\]\\[(.*?)\\]", options: [])
private let boldRegex = try! NSRegularExpression(pattern: "((\\*|_){2})((?!\\1).)+\\1", options: [])
private let underscoreEmphasisRegex = try! NSRegularExpression(pattern: "(?<!_)_[^_]+_(?!\\*)", options: [])
private let asteriskEmphasisRegex = try! NSRegularExpression(pattern: "(?<!\\*)(\\*)((?!\\1).)+\\1(?!\\*)", options: [])
private let boldEmphasisAsteriskRegex = try! NSRegularExpression(pattern: "(\\*){3}((?!\\1).)+\\1{3}", options: [])
private let blockquoteRegex = try! NSRegularExpression(pattern: "^>.*", options: [.anchorsMatchLines])
private let horizontalRuleRegex = try! NSRegularExpression(pattern: "\n\n(-{3}|\\*{3})\n", options: [])
private let unorderedListRegex = try! NSRegularExpression(pattern: "^(\\-|\\*)\\s", options: [.anchorsMatchLines])
private let orderedListRegex = try! NSRegularExpression(pattern: "^\\d*\\.\\s", options: [.anchorsMatchLines])
private let buttonRegex = try! NSRegularExpression(pattern: "<\\s*button[^>]*>(.*?)<\\s*/\\s*button>", options: [])
private let strikethroughRegex = try! NSRegularExpression(pattern: "(~)((?!\\1).)+\\1", options: [])
private let tagRegex = try! NSRegularExpression(pattern: "^\\[([^\\[\\]]*)\\]:", options: [.anchorsMatchLines])
private let footnoteRegex = try! NSRegularExpression(pattern: "\\[\\^(.*?)\\]", options: [])
// courtesy https://www.regular-expressions.info/examples.html
private let htmlRegex = try! NSRegularExpression(
    pattern: "<([A-Z][A-Z0-9]*)\\b[^>]*>(.*?)</\\1>",
    options: [.dotMatchesLineSeparators, .caseInsensitive]
)

private let doubleQuoteRegex = try! NSRegularExpression(pattern: "\"[^\"\n]*\"", options: [])
private let singleQuoteRegex = try! NSRegularExpression(pattern: "'[^'\n]*'", options: [])
private let curlyBraceRegex = try! NSRegularExpression(pattern: "\\{[^}\n]*\\}", options: [])
private let squareBracketRegex = try! NSRegularExpression(pattern: "\\[[^\\]\n]*\\]", options: [])
private let jsonKeyRegex = try! NSRegularExpression(pattern: "\"[^\"\n]*\"\\s*:", options: [])

// MARK: - Theme

public struct MarkdownTheme {
    public var codeFont: SystemFontAlias
    public var headingTraits: SymbolicTraits
    public var boldTraits: SymbolicTraits
    public var emphasisTraits: SymbolicTraits
    public var boldEmphasisTraits: SymbolicTraits
    public var codeBackground: SystemColorAlias
    public var codeColor: SystemColorAlias?        // nil = inherit text color
    public var blockquoteBackground: SystemColorAlias
    public var syntaxColor: SystemColorAlias        // -, >, list markers, etc.
    public var markupColor: SystemColorAlias?       // #, *, _, ` markers — nil = use syntaxColor
    public var textColor: SystemColorAlias
    public var stringColor: SystemColorAlias?     // nil = no highlight for "quotes" and 'quotes'
    public var bracketColor: SystemColorAlias?    // nil = no highlight for {braces} and [brackets]
    public var keyColor: SystemColorAlias?         // nil = no highlight for JSON keys ("key":)
    public var codeKeyColor: SystemColorAlias?     // nil = no highlight for JSON keys inside code
    public var codeStringColor: SystemColorAlias? // nil = no highlight for quotes inside code
    public var codeBracketColor: SystemColorAlias? // nil = no highlight for brackets inside code
    public var paragraphSpacing: CGFloat?        // nil = default (no override), points between paragraphs
    public var linkUnderline: Bool

    /// Code font uses the current `editorFontSize` from UserDefaults (thin weight).
    public static var codeFontCurrent: SystemFontAlias {
        let stored = UserDefaults.standard.double(forKey: editorFontSizeKey)
        let size = stored > 0 ? CGFloat(stored) : editorFontSizeDefault
        return SystemFontAlias.monospacedSystemFont(ofSize: size, weight: .thin)
    }

    #if os(macOS)
    public static var `default`: MarkdownTheme {
        MarkdownTheme(
            codeFont: codeFontCurrent,
            headingTraits: [.bold, .expanded],
            boldTraits: [.bold],
            emphasisTraits: [.italic],
            boldEmphasisTraits: [.bold, .italic],
            codeBackground: NSColor(white: 0.5, alpha: 0.15),
            codeColor: nil,
            blockquoteBackground: NSColor.windowBackgroundColor,
            syntaxColor: NSColor.lightGray,
            markupColor: nil,
            textColor: NSColor.labelColor,
            stringColor: nil,
            bracketColor: nil,
            keyColor: nil,
            codeKeyColor: nil,
            codeStringColor: nil,
            codeBracketColor: nil,
            paragraphSpacing: nil,
            linkUnderline: true
        )
    }
    #else
    public static var `default`: MarkdownTheme {
        MarkdownTheme(
            codeFont: codeFontCurrent,
            headingTraits: [.traitBold, .traitExpanded],
            boldTraits: [.traitBold],
            emphasisTraits: [.traitItalic],
            boldEmphasisTraits: [.traitBold, .traitItalic],
            codeBackground: UIColor(white: 0.5, alpha: 0.15),
            codeColor: nil,
            blockquoteBackground: UIColor.secondarySystemBackground,
            syntaxColor: UIColor.lightGray,
            markupColor: nil,
            textColor: UIColor.label,
            stringColor: nil,
            bracketColor: nil,
            keyColor: nil,
            codeKeyColor: nil,
            codeStringColor: nil,
            codeBracketColor: nil,
            paragraphSpacing: nil,
            linkUnderline: true
        )
    }
    #endif

    /// Minimal theme — no background tints, subtle syntax markers
    public static let minimal: MarkdownTheme = {
        var theme = MarkdownTheme.default
        #if os(macOS)
        theme.codeBackground = NSColor.clear
        theme.blockquoteBackground = NSColor.clear
        theme.syntaxColor = NSColor.tertiaryLabelColor
        #else
        theme.codeBackground = UIColor.clear
        theme.blockquoteBackground = UIColor.clear
        theme.syntaxColor = UIColor.tertiaryLabel
        #endif
        theme.linkUnderline = false
        return theme
    }()
}

// MARK: - Rules builder

public extension Sequence where Iterator.Element == HighlightRule {
    static var markdown: [HighlightRule] {
        markdown(theme: .default)
    }

    static func markdown(theme: MarkdownTheme) -> [HighlightRule] {
        let mc = theme.markupColor ?? theme.syntaxColor

        // Quotes & brackets inside code (ignoresExclusion — applies everywhere, will be overridden outside code by normal rules below)
        var codeQuoteBracketRules: [HighlightRule] = []
        if let cs = theme.codeStringColor {
            codeQuoteBracketRules.append(HighlightRule(pattern: doubleQuoteRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: cs), ignoresExclusion: true))
            codeQuoteBracketRules.append(HighlightRule(pattern: singleQuoteRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: cs), ignoresExclusion: true))
        }
        if let cb = theme.codeBracketColor {
            codeQuoteBracketRules.append(HighlightRule(pattern: curlyBraceRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: cb), ignoresExclusion: true))
            codeQuoteBracketRules.append(HighlightRule(pattern: squareBracketRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: cb), ignoresExclusion: true))
        }
        if let ck = theme.codeKeyColor {
            codeQuoteBracketRules.append(HighlightRule(pattern: jsonKeyRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: ck), ignoresExclusion: true))
        }

        // Quotes & brackets in regular text (non-exclusive, blocked inside code)
        var textQuoteBracketRules: [HighlightRule] = []
        if let sc = theme.stringColor {
            textQuoteBracketRules.append(HighlightRule(pattern: doubleQuoteRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: sc)))
            textQuoteBracketRules.append(HighlightRule(pattern: singleQuoteRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: sc)))
        }
        if let bc = theme.bracketColor {
            textQuoteBracketRules.append(HighlightRule(pattern: curlyBraceRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: bc)))
            textQuoteBracketRules.append(HighlightRule(pattern: squareBracketRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: bc)))
        }
        if let kc = theme.keyColor {
            textQuoteBracketRules.append(HighlightRule(pattern: jsonKeyRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: kc)))
        }

        return [
            HighlightRule(pattern: inlineCodeRegex, formattingRules: {
                var rules: [TextFormattingRule] = [
                    TextFormattingRule(key: .font, value: theme.codeFont),
                    TextFormattingRule(key: .backgroundColor, value: theme.codeBackground)
                ]
                if let color = theme.codeColor {
                    rules.append(TextFormattingRule(key: .foregroundColor, value: color))
                }
                return rules
            }(), isExclusive: true),
            HighlightRule(pattern: codeBlockRegex, formattingRules: {
                var rules: [TextFormattingRule] = [
                    TextFormattingRule(key: .font, value: theme.codeFont),
                    TextFormattingRule(key: .backgroundColor, value: theme.codeBackground)
                ]
                if let color = theme.codeColor {
                    rules.append(TextFormattingRule(key: .foregroundColor, value: color))
                }
                return rules
            }(), isExclusive: true),
            HighlightRule(pattern: headingRegex, formattingRule: TextFormattingRule(fontTraits: theme.boldTraits)),
            HighlightRule(
                pattern: linkOrImageRegex,
                formattingRule: theme.linkUnderline
                    ? TextFormattingRule(key: .underlineStyle, value: NSUnderlineStyle.single.rawValue)
                    : TextFormattingRule(key: .foregroundColor, value: theme.syntaxColor)
            ),
            HighlightRule(
                pattern: linkOrImageTagRegex,
                formattingRule: theme.linkUnderline
                    ? TextFormattingRule(key: .underlineStyle, value: NSUnderlineStyle.single.rawValue)
                    : TextFormattingRule(key: .foregroundColor, value: theme.syntaxColor)
            ),
            HighlightRule(pattern: boldRegex, formattingRule: TextFormattingRule(fontTraits: theme.boldTraits)),
            HighlightRule(
                pattern: asteriskEmphasisRegex,
                formattingRule: TextFormattingRule(fontTraits: theme.emphasisTraits)
            ),
            HighlightRule(
                pattern: underscoreEmphasisRegex,
                formattingRule: TextFormattingRule(fontTraits: theme.emphasisTraits)
            ),
            HighlightRule(
                pattern: boldEmphasisAsteriskRegex,
                formattingRule: TextFormattingRule(fontTraits: theme.boldEmphasisTraits)
            ),
            HighlightRule(
                pattern: blockquoteRegex,
                formattingRule: TextFormattingRule(key: .backgroundColor, value: theme.blockquoteBackground)
            ),
            HighlightRule(
                pattern: horizontalRuleRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: theme.syntaxColor)
            ),
            HighlightRule(
                pattern: unorderedListRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: theme.syntaxColor)
            ),
            HighlightRule(
                pattern: orderedListRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: theme.syntaxColor)
            ),
            HighlightRule(
                pattern: buttonRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: theme.syntaxColor)
            ),
            HighlightRule(pattern: strikethroughRegex, formattingRules: [
                TextFormattingRule(key: .strikethroughStyle, value: NSUnderlineStyle.single.rawValue),
                TextFormattingRule(key: .strikethroughColor, value: theme.textColor)
            ]),
            HighlightRule(
                pattern: tagRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: theme.syntaxColor)
            ),
            HighlightRule(
                pattern: footnoteRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: theme.syntaxColor)
            ),
            HighlightRule(pattern: htmlRegex, formattingRules: [
                TextFormattingRule(key: .font, value: theme.codeFont),
                TextFormattingRule(key: .foregroundColor, value: theme.syntaxColor)
            ]),
            // Markup markers: #, **, __, *, _
            HighlightRule(pattern: headingMarkerRegex, formattingRule:
                TextFormattingRule(key: .foregroundColor, value: mc)),
            HighlightRule(pattern: boldMarkerRegex, formattingRule:
                TextFormattingRule(key: .foregroundColor, value: mc)),
            HighlightRule(pattern: emphasisMarkerRegex, formattingRule:
                TextFormattingRule(key: .foregroundColor, value: mc)),
        ] + codeQuoteBracketRules + textQuoteBracketRules
    }
}
