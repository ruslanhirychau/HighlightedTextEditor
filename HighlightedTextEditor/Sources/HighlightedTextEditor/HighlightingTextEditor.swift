//
//  HighlightingTextEditor.swift
//
//
//  Created by Kyle Nazario on 8/31/20.
//

import SwiftUI

#if os(macOS)
import AppKit

public typealias SystemFontAlias = NSFont
public typealias SystemColorAlias = NSColor
public typealias SymbolicTraits = NSFontDescriptor.SymbolicTraits
public typealias SystemTextView = NSTextView
public typealias SystemScrollView = NSScrollView

public let editorFontSizeKey = "editorFontSize"
public let editorFontSizeDefault: CGFloat = 14
public let editorParagraphSpacingKey = "editorParagraphSpacing"
public let editorParagraphSpacingDefault: CGFloat = 0
public let editorLineHeightKey = "editorLineHeight"
public let editorLineHeightDefault: CGFloat = 1.0

var defaultEditorFont: NSFont {
    let stored = UserDefaults.standard.double(forKey: editorFontSizeKey)
    let size = stored > 0 ? CGFloat(stored) : editorFontSizeDefault
    return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
}
let defaultEditorTextColor = NSColor.labelColor

#else
import UIKit

public typealias SystemFontAlias = UIFont
public typealias SystemColorAlias = UIColor
public typealias SymbolicTraits = UIFontDescriptor.SymbolicTraits
public typealias SystemTextView = UITextView
public typealias SystemScrollView = UIScrollView

public let editorFontSizeKey = "editorFontSize"
public let editorFontSizeDefault: CGFloat = 14
public let editorParagraphSpacingKey = "editorParagraphSpacing"
public let editorParagraphSpacingDefault: CGFloat = 0
public let editorLineHeightKey = "editorLineHeight"
public let editorLineHeightDefault: CGFloat = 1.0

var defaultEditorFont: UIFont {
    let stored = UserDefaults.standard.double(forKey: editorFontSizeKey)
    let size = stored > 0 ? CGFloat(stored) : editorFontSizeDefault
    return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
}
let defaultEditorTextColor = UIColor.label

#endif

public struct TextFormattingRule {
    public typealias AttributedKeyCallback = (String, Range<String.Index>) -> Any

    let key: NSAttributedString.Key?
    let calculateValue: AttributedKeyCallback?
    let fontTraits: SymbolicTraits

    // ------------------- convenience ------------------------

    public init(key: NSAttributedString.Key, value: Any) {
        self.init(key: key, calculateValue: { _, _ in value }, fontTraits: [])
    }

    public init(key: NSAttributedString.Key, calculateValue: @escaping AttributedKeyCallback) {
        self.init(key: key, calculateValue: calculateValue, fontTraits: [])
    }

    public init(fontTraits: SymbolicTraits) {
        self.init(key: nil, fontTraits: fontTraits)
    }

    // ------------------ most powerful initializer ------------------

    init(
        key: NSAttributedString.Key? = nil,
        calculateValue: AttributedKeyCallback? = nil,
        fontTraits: SymbolicTraits = []
    ) {
        self.key = key
        self.calculateValue = calculateValue
        self.fontTraits = fontTraits
    }
}

public struct HighlightRule {
    let pattern: NSRegularExpression
    let formattingRules: [TextFormattingRule]
    /// Если true — совпадения этого правила блокируют применение других правил на тех же диапазонах.
    /// Используется для блоков кода, чтобы внутри них не срабатывал italic, bold и т.д.
    let isExclusive: Bool
    /// Если true — правило применяется даже внутри exclusive-зон (например, внутри кода).
    let ignoresExclusion: Bool

    // ------------------- convenience ------------------------

    public init(pattern: NSRegularExpression, formattingRule: TextFormattingRule, isExclusive: Bool = false, ignoresExclusion: Bool = false) {
        self.init(pattern: pattern, formattingRules: [formattingRule], isExclusive: isExclusive, ignoresExclusion: ignoresExclusion)
    }

    // ------------------ most powerful initializer ------------------

    public init(pattern: NSRegularExpression, formattingRules: [TextFormattingRule], isExclusive: Bool = false, ignoresExclusion: Bool = false) {
        self.pattern = pattern
        self.formattingRules = formattingRules
        self.isExclusive = isExclusive
        self.ignoresExclusion = ignoresExclusion
    }
}

internal protocol HighlightingTextEditor {
    var text: String { get set }
    var highlightRules: [HighlightRule] { get }
}

public typealias OnSelectionChangeCallback = ([NSRange]) -> Void
public typealias IntrospectCallback = (_ editor: HighlightedTextEditor.Internals) -> Void
public typealias EmptyCallback = () -> Void
public typealias OnCommitCallback = EmptyCallback
public typealias OnEditingChangedCallback = EmptyCallback
public typealias OnTextChangeCallback = (_ editorContent: String) -> Void

extension HighlightingTextEditor {
    var placeholderFont: SystemColorAlias { SystemColorAlias() }

    static func getHighlightedText(text: String, highlightRules: [HighlightRule]) -> NSMutableAttributedString {
        let highlightedString = NSMutableAttributedString(string: text)
        let all = NSRange(location: 0, length: text.utf16.count)

        let editorFont = defaultEditorFont
        let editorTextColor = defaultEditorTextColor

        highlightedString.addAttribute(.font, value: editorFont, range: all)
        highlightedString.addAttribute(.foregroundColor, value: editorTextColor, range: all)

        let storedPS = UserDefaults.standard.double(forKey: editorParagraphSpacingKey)
        let paragraphSpacing = storedPS > 0 ? CGFloat(storedPS) : editorParagraphSpacingDefault
        let storedLH = UserDefaults.standard.double(forKey: editorLineHeightKey)
        let lineHeight = storedLH > 0 ? CGFloat(storedLH) : editorLineHeightDefault
        if paragraphSpacing > 0 || lineHeight > 1.0 {
            let para = NSMutableParagraphStyle()
            if paragraphSpacing > 0 { para.paragraphSpacing = paragraphSpacing }
            if lineHeight > 1.0 { para.lineHeightMultiple = lineHeight }
            highlightedString.addAttribute(.paragraphStyle, value: para, range: all)
        }

        let exclusionZones: [NSRange] = highlightRules
            .filter { $0.isExclusive }
            .flatMap { rule in rule.pattern.matches(in: text, options: [], range: all).map { $0.range } }

        highlightRules.forEach { rule in
            let matches = rule.pattern.matches(in: text, options: [], range: all)
            matches.forEach { match in
                if !rule.isExclusive && !rule.ignoresExclusion {
                    // Skip if match overlaps an exclusion zone, UNLESS the match fully contains it
                    // (e.g. a heading line containing inline code should still get bold)
                    let isExcluded = exclusionZones.contains { zone in
                        let intersection = NSIntersectionRange(zone, match.range)
                        guard intersection.length > 0 else { return false }
                        let matchContainsZone = match.range.location <= zone.location &&
                            (match.range.location + match.range.length) >= (zone.location + zone.length)
                        return !matchContainsZone
                    }
                    if isExcluded { return }
                }
                rule.formattingRules.forEach { formattingRule in

                    var font = SystemFontAlias()
                    highlightedString.enumerateAttributes(in: match.range, options: []) { attributes, _, _ in
                        let fontAttribute = attributes.first { $0.key == .font }!
                        // swiftlint:disable:next force_cast
                        let previousFont = fontAttribute.value as! SystemFontAlias
                        font = previousFont.with(formattingRule.fontTraits)
                    }
                    highlightedString.addAttribute(.font, value: font, range: match.range)

                    let matchRange = Range<String.Index>(match.range, in: text)!
                    let matchContent = String(text[matchRange])
                    guard let key = formattingRule.key,
                          let calculateValue = formattingRule.calculateValue else { return }
                    highlightedString.addAttribute(
                        key,
                        value: calculateValue(matchContent, matchRange),
                        range: match.range
                    )
                }
            }
        }

        return highlightedString
    }
}
