import SwiftUI

struct ImagePickerView: UIViewControllerRepresentable {
    enum SourceType {
        case camera
        case photoLibrary
    }

    let sourceType: SourceType
    let onImagePicked: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType == .camera ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (Data) -> Void

        init(onImagePicked: @escaping (Data) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                let data = image.jpegData(compressionQuality: 0.7)
                if let data = data {
                    onImagePicked(data)
                }
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Inline image markdown helpers
//
// Images are embedded inside the text as Markdown image syntax with a base64
// data URI, e.g.  ![图](data:image/jpeg;base64,....)

enum InlineImageMarkdown {
    struct Segment {
        let text: String
        let imageData: Data?

        var isImage: Bool { imageData != nil }
    }

    /// Matches ![alt](data:image/jpeg;base64,....)
    private static let tokenRegex = try! NSRegularExpression(
        pattern: #"!\[[^\]]*\]\(data:image/(jpeg|png|jpg|gif);base64,([^)]+)\)"#,
        options: []
    )

    /// Split a string into text / image segments, preserving order.
    static func segments(in string: String) -> [Segment] {
        var result: [Segment] = []
        let ns = string as NSString
        let matches = tokenRegex.matches(in: string, range: NSRange(location: 0, length: ns.length))
        var cursor = 0
        for m in matches {
            if m.range.location > cursor {
                result.append(Segment(
                    text: ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor)),
                    imageData: nil
                ))
            }
            let full = ns.substring(with: m.range)
            let b64 = ns.substring(with: m.range(at: 2))
            if let data = Data(base64Encoded: b64) {
                result.append(Segment(text: "", imageData: data))
            } else {
                // Un-decodable token: keep it as literal text so nothing is lost.
                result.append(Segment(text: full, imageData: nil))
            }
            cursor = NSMaxRange(m.range)
        }
        if cursor < ns.length {
            result.append(Segment(
                text: ns.substring(with: NSRange(location: cursor, length: ns.length - cursor)),
                imageData: nil
            ))
        }
        return result
    }

    /// Markdown string → attributed string with inline image attachments.
    static func attributedString(from string: String, font: UIFont) -> NSAttributedString {
        let mutable = NSMutableAttributedString()
        for seg in segments(in: string) {
            if seg.isImage, let data = seg.imageData, let image = UIImage(data: data) {
                let attachment = ImageAttachment(imageData: data)
                attachment.bounds = CGRect(origin: .zero, size: displaySize(for: image, maxWidth: 200))
                mutable.append(NSAttributedString(attachment: attachment))
            } else {
                mutable.append(NSAttributedString(
                    string: seg.text,
                    attributes: [.font: font, .foregroundColor: UIColor.label]
                ))
            }
        }
        return mutable
    }

    /// Attributed string → markdown string with base64 data URIs.
    static func markdown(from attributed: NSAttributedString) -> String {
        var result = ""
        var i = 0
        let length = attributed.length
        while i < length {
            var effectiveRange = NSRange(location: 0, length: 0)
            if let attachment = attributed.attribute(.attachment, at: i, effectiveRange: &effectiveRange) as? ImageAttachment {
                result += "![image](data:image/jpeg;base64,\(attachment.imageData.base64EncodedString()))"
                i = NSMaxRange(effectiveRange)
            } else {
                result += attributed.attributedSubstring(from: NSRange(location: i, length: 1)).string
                i += 1
            }
        }
        return result
    }

    /// Replace inline images with a placeholder (used for plain-text export).
    static func stripped(forPlainText string: String) -> String {
        segments(in: string)
            .map { $0.isImage ? "[图片]" : $0.text }
            .joined()
    }

    /// Scaled display size that fits inside a given max width, keeping aspect ratio.
    static func displaySize(for image: UIImage, maxWidth: CGFloat) -> CGSize {
        let width = min(maxWidth, max(image.size.width, 1))
        let ratio = image.size.height / max(image.size.width, 1)
        return CGSize(width: width, height: width * ratio)
    }
}

/// NSTextAttachment that remembers the original image data for round-tripping.
final class ImageAttachment: NSTextAttachment {
    let imageData: Data

    init(imageData: Data) {
        self.imageData = imageData
        super.init(data: nil, ofType: nil)
        self.image = UIImage(data: imageData)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// A multi-line rich text editor that supports font styles (bold / italic /
/// underline / color / size) and inserting images at the current cursor
/// position. The bound string is stored in a JSON "runs" format (see
/// `RichText`); legacy Markdown content is migrated when first edited.
struct InlineImageTextView: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont = .preferredFont(forTextStyle: .body)

    /// When non-nil, the image is inserted at the current selection, then
    /// `onImageInserted` is called so the parent can reset the trigger.
    var imageToInsert: Data?
    var onImageInserted: (() -> Void)?

    /// When non-nil, the format is applied to the current selection, then
    /// `onFormatApplied` is called so the parent can reset the trigger.
    var pendingFormat: RichFormat?
    var onFormatApplied: (() -> Void)?

    // MARK: - Toolbar (rendered as inputAccessoryView above the keyboard)

    var onFormat: ((RichFormat) -> Void)?
    var onCamera: (() -> Void)?
    var onLibrary: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = font
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.textContainer.heightTracksTextView = true
        tv.textContainer.widthTracksTextView = true
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        context.coordinator.textView = tv
        tv.typingAttributes = [.font: font, .foregroundColor: UIColor.label]
        tv.attributedText = RichText.attributedString(from: text, font: font)

        // 格式工具栏放在键盘上方，编辑任意位置都能用到
        if onFormat != nil || onCamera != nil || onLibrary != nil {
            let toolbar = RichTextToolbar(
                state: .init(),
                onFormat: onFormat ?? { _ in },
                onCamera: onCamera ?? {},
                onLibrary: onLibrary ?? {},
                onDismissKeyboard: { [weak tv] in tv?.resignFirstResponder() }
            )
            let host = UIHostingController(rootView: toolbar)
            host.view.backgroundColor = UIColor.secondarySystemBackground
            let width = UIScreen.main.bounds.width
            let size = host.sizeThatFits(in: CGSize(width: width, height: 60))
            host.view.frame = CGRect(origin: .zero, size: CGSize(width: width, height: max(size.height, 44)))
            tv.inputAccessoryView = host.view
            context.coordinator.toolbarHost = host
        }

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if RichText.serialized(from: uiView.attributedText) != text {
            uiView.attributedText = RichText.attributedString(from: text, font: font)
        }
        if let data = imageToInsert {
            context.coordinator.insertImage(data, into: uiView)
            onImageInserted?()
        }
        if let format = pendingFormat {
            context.coordinator.applyFormat(format, to: uiView)
            onFormatApplied?()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: InlineImageTextView
        var toolbarHost: UIHostingController<RichTextToolbar>?
        weak var textView: UITextView?

        var toolbarState = RichToolbarState() {
            didSet {
                guard oldValue != toolbarState, let host = toolbarHost else { return }
                host.rootView = RichTextToolbar(
                    state: toolbarState,
                    onFormat: parent.onFormat ?? { _ in },
                    onCamera: parent.onCamera ?? {},
                    onLibrary: parent.onLibrary ?? {},
                    onDismissKeyboard: { [weak self] in
                        self?.textView?.resignFirstResponder()
                    }
                )
            }
        }

        init(_ parent: InlineImageTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            textView.invalidateIntrinsicContentSize()
            parent.text = RichText.serialized(from: textView.attributedText)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            readToolbarState(from: textView)
        }

        private func readToolbarState(from tv: UITextView) {
            let attrs: [NSAttributedString.Key: Any]
            if tv.selectedRange.length > 0 {
                attrs = tv.attributedText.attributes(at: tv.selectedRange.location, effectiveRange: nil)
            } else {
                attrs = tv.typingAttributes
            }
            var state = RichToolbarState()
            if let font = attrs[.font] as? UIFont {
                state.isBold = font.isBold
            }
            if let us = attrs[.underlineStyle] as? Int, us != 0 {
                state.isUnderline = true
            }
            if let color = attrs[.foregroundColor] as? UIColor, color != UIColor.label {
                state.activeColorHex = color.hexString
            }
            toolbarState = state
        }

        func insertImage(_ data: Data, into tv: UITextView) {
            let attachment = ImageAttachment(imageData: data)
            if let image = attachment.image {
                attachment.bounds = CGRect(origin: .zero, size: InlineImageMarkdown.displaySize(for: image, maxWidth: 200))
            }
            let loc = tv.selectedRange.location
            let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
            mutable.insert(NSAttributedString(attachment: attachment), at: loc)
            tv.attributedText = mutable
            tv.selectedRange = NSRange(location: loc + 1, length: 0)
            tv.invalidateIntrinsicContentSize()
            parent.text = RichText.serialized(from: tv.attributedText)
        }

        /// Apply a format to the current selection (or to typing attributes if
        /// there is no selection), then push the change to the binding.
        func applyFormat(_ format: RichFormat, to tv: UITextView) {
            let range = tv.selectedRange
            let length = tv.attributedText.length
            let clamped = NSIntersectionRange(range, NSRange(location: 0, length: length))

            guard clamped.length > 0 else {
                updateTypingAttributes(format, tv: tv)
                return
            }

            let existing = tv.attributedText.attributes(at: clamped.location, effectiveRange: nil)
            var font = (existing[.font] as? UIFont) ?? parent.font
            var color = (existing[.foregroundColor] as? UIColor) ?? UIColor.label
            var underline = (existing[.underlineStyle] as? Int) ?? 0
            let isBold = font.isBold
            let isItalic = font.isItalic

            switch format {
            case .bold:
                font = RichText.makeFont(size: font.pointSize, bold: !isBold, italic: isItalic)
            case .italic:
                font = RichText.makeFont(size: font.pointSize, bold: isBold, italic: !isItalic)
            case .underline:
                underline = underline == 0 ? NSUnderlineStyle.single.rawValue : 0
            case .color(let hex):
                if let c = UIColor(hex: hex) { color = c }
            case .size(let pt):
                font = RichText.makeFont(size: pt, bold: isBold, italic: isItalic)
            }

            let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
            mutable.addAttributes([.font: font, .foregroundColor: color, .underlineStyle: underline], range: clamped)
            tv.attributedText = mutable
            tv.selectedRange = range
            tv.invalidateIntrinsicContentSize()
            parent.text = RichText.serialized(from: tv.attributedText)
            readToolbarState(from: tv)
        }

        private func updateTypingAttributes(_ format: RichFormat, tv: UITextView) {
            var attrs = tv.typingAttributes
            var font = (attrs[.font] as? UIFont) ?? parent.font
            var color = (attrs[.foregroundColor] as? UIColor) ?? UIColor.label
            var underline = (attrs[.underlineStyle] as? Int) ?? 0
            let isBold = font.isBold
            let isItalic = font.isItalic

            switch format {
            case .bold:
                font = RichText.makeFont(size: font.pointSize, bold: !isBold, italic: isItalic)
            case .italic:
                font = RichText.makeFont(size: font.pointSize, bold: isBold, italic: !isItalic)
            case .underline:
                underline = underline == 0 ? NSUnderlineStyle.single.rawValue : 0
            case .color(let hex):
                if let c = UIColor(hex: hex) { color = c }
            case .size(let pt):
                font = RichText.makeFont(size: pt, bold: isBold, italic: isItalic)
            }

            attrs[.font] = font
            attrs[.foregroundColor] = color
            attrs[.underlineStyle] = underline
            tv.typingAttributes = attrs
            readToolbarState(from: tv)
        }
    }
}

// MARK: - Rich text format

/// A formatting action that can be applied to the text editor selection.
enum RichFormat {
    case bold
    case italic
    case underline
    case color(String)
    case size(CGFloat)
}

/// Serializes / parses rich text between a JSON "runs" string and an
/// `NSAttributedString`. Format:
/// ```
/// {"v":1,"runs":[{"type":"text","s":"..","b":true,"c":"#FF0000","size":18},
///                 {"type":"image","data":"<base64>"}]}
/// ```
enum RichText {
    static let presetColors: [(String, String)] = [
        ("黑色", "#000000"),
        ("灰色", "#8E8E93"),
        ("红色", "#FF3B30"),
        ("橙色", "#FF9500"),
        ("黄色", "#FFCC00"),
        ("绿色", "#34C759"),
        ("蓝色", "#007AFF"),
        ("紫色", "#AF52DE"),
        ("薰衣草", "#B08CD9"),
    ]

    static let presetSizes: [CGFloat] = [15, 17, 20, 24, 28, 36, 48]

    static func isRich(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runs = json["runs"] as? [[String: Any]] else { return false }
        return (json["v"] as? Int) == 1 && !runs.isEmpty
    }

    /// 内容里是否包含内嵌图片（data URI 或富文本 image run）
    static func containsImage(_ string: String) -> Bool {
        if string.contains("data:image/") { return true }
        if !isRich(string) { return false }
        return runs(from: string).contains { ($0["type"] as? String) == "image" }
    }

    static func runs(from string: String) -> [[String: Any]] {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runs = json["runs"] as? [[String: Any]] else { return [] }
        return runs
    }

    /// Plain text version (images become a placeholder) for search / export.
    static func plainText(from string: String) -> String {
        var out = ""
        for run in runs(from: string) {
            if (run["type"] as? String) == "image" {
                out += "[图片]"
            } else {
                out += (run["s"] as? String) ?? ""
            }
        }
        return out
    }

    /// Export-friendly text: rich → plain text; legacy Markdown → text with
    /// data-URI images stripped.
    static func exportText(from string: String) -> String {
        if isRich(string) { return plainText(from: string) }
        return InlineImageMarkdown.stripped(forPlainText: string)
    }

    /// Serialize an attributed string (with formatting + image attachments)
    /// into the JSON "runs" format.
    static func serialized(from attributed: NSAttributedString) -> String {
        var runs: [[String: Any]] = []
        var i = 0
        let length = attributed.length
        while i < length {
            var effectiveRange = NSRange(location: 0, length: 0)
            let attrs = attributed.attributes(at: i, effectiveRange: &effectiveRange)
            var dict: [String: Any] = ["type": "text"]

            if let attachment = attrs[.attachment] as? ImageAttachment {
                dict["type"] = "image"
                dict["data"] = attachment.imageData.base64EncodedString()
            } else {
                dict["s"] = attributed.attributedSubstring(from: effectiveRange).string
                if let font = attrs[.font] as? UIFont {
                    if font.isBold { dict["b"] = true }
                    if font.isItalic { dict["i"] = true }
                    if font.pointSize != UIFont.labelFontSize { dict["size"] = Double(font.pointSize) }
                }
                if let color = attrs[.foregroundColor] as? UIColor, !color.isEqual(UIColor.label) {
                    dict["c"] = color.hexString
                }
                if let us = attrs[.underlineStyle] as? Int, us != 0 {
                    dict["u"] = true
                }
            }
            runs.append(dict)
            i = NSMaxRange(effectiveRange)
        }

        guard !runs.isEmpty else { return "" }

        let root: [String: Any] = ["v": 1, "runs": runs]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: .sortedKeys),
              let str = String(data: data, encoding: .utf8) else {
            return InlineImageMarkdown.markdown(from: attributed)
        }
        return str
    }

    /// Parse a stored string into an attributed string. Rich JSON is decoded;
    /// anything else (legacy Markdown / plain text) is shown as plain text
    /// with data-URI images.
    static func attributedString(from string: String, font: UIFont) -> NSAttributedString {
        let rawRuns = runs(from: string)
        guard !rawRuns.isEmpty else {
            return InlineImageMarkdown.attributedString(from: string, font: font)
        }

        let mutable = NSMutableAttributedString()
        for run in rawRuns {
            if (run["type"] as? String) == "image",
               let b64 = run["data"] as? String,
               let data = Data(base64Encoded: b64),
               let uiImage = UIImage(data: data) {
                let attachment = ImageAttachment(imageData: data)
                attachment.bounds = CGRect(origin: .zero, size: InlineImageMarkdown.displaySize(for: uiImage, maxWidth: 200))
                mutable.append(NSAttributedString(attachment: attachment))
                continue
            }

            guard let s = run["s"] as? String, !s.isEmpty else { continue }
            let size = (run["size"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? font.pointSize
            let bold = (run["b"] as? Bool) ?? false
            let italic = (run["i"] as? Bool) ?? false
            var attrs: [NSAttributedString.Key: Any] = [
                .font: makeFont(size: size, bold: bold, italic: italic),
                .foregroundColor: UIColor.label,
            ]
            if let c = run["c"] as? String, let color = UIColor(hex: c) {
                attrs[.foregroundColor] = color
            }
            if (run["u"] as? Bool) == true {
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            mutable.append(NSAttributedString(string: s, attributes: attrs))
        }
        return mutable
    }

    static func makeFont(size: CGFloat, bold: Bool, italic: Bool) -> UIFont {
        if italic {
            let base = UIFont.italicSystemFont(ofSize: size)
            if bold, let desc = base.fontDescriptor.withSymbolicTraits(.traitBold) {
                return UIFont(descriptor: desc, size: size)
            }
            return base
        }
        if bold {
            if let desc = UIFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits(.traitBold) {
                return UIFont(descriptor: desc, size: size)
            }
            return UIFont.boldSystemFont(ofSize: size)
        }
        return UIFont.systemFont(ofSize: size)
    }
}

extension UIFont {
    var isBold: Bool { fontDescriptor.symbolicTraits.contains(.traitBold) }
    var isItalic: Bool { fontDescriptor.symbolicTraits.contains(.traitItalic) }
}

// MARK: - Rich text toolbar

/// Current formatting state at the cursor — so toolbar buttons can show active status.
struct RichToolbarState: Equatable {
    var isBold = false
    var isUnderline = false
    var activeColorHex: String? = nil
}

/// Formatting toolbar for the rich text editor (bold / italic / underline /
/// color / size / image).
struct RichTextToolbar: View {
    var state: RichToolbarState
    var onFormat: (RichFormat) -> Void
    var onCamera: () -> Void
    var onLibrary: () -> Void
    var onDismissKeyboard: (() -> Void)?

    private let accent = Color.lavender
    private let inactive = Color.secondary

    /// 用 UIKit 渲染一个实心圆图片，避免 Menu 对 SwiftUI Shape 的裁剪 / 染色问题.
    private static func colorCircle(_ hex: String) -> UIImage {
        let side: CGFloat = 16
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(
                (UIColor(hex: hex) ?? UIColor.gray).cgColor
            )
            ctx.cgContext.fillEllipse(in: CGRect(x: 1, y: 1, width: side - 2, height: side - 2))
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Button { onFormat(.bold) } label: {
                Text("B").font(.headline).fontWeight(.heavy)
            }
            .foregroundStyle(state.isBold ? accent : inactive)
            .buttonStyle(.plain)

            Button { onFormat(.underline) } label: {
                Text("U").font(.headline).underline()
            }
            .foregroundStyle(state.isUnderline ? accent : inactive)
            .buttonStyle(.plain)

            // 颜色选择：用预渲染位图，绕过 Menu 对 SwiftUI Shape 的裁剪
            Menu {
                ForEach(RichText.presetColors, id: \.1) { name, hex in
                    Button {
                        onFormat(.color(hex))
                    } label: {
                        Label {
                            Text(name)
                        } icon: {
                            Image(uiImage: Self.colorCircle(hex))
                                .renderingMode(.original)
                        }
                    }
                }
            } label: {
                Image(systemName: "paintbrush.pointed.fill")
                    .foregroundStyle(
                        state.activeColorHex != nil ? Color(hex: state.activeColorHex!) : accent
                    )
            }

            Menu {
                ForEach(RichText.presetSizes, id: \.self) { pt in
                    Button("\(Int(pt))") { onFormat(.size(pt)) }
                }
            } label: {
                Image(systemName: "textformat.size")
            }

            Menu {
                Button(action: onCamera) {
                    Label("Take Photo", systemImage: "camera")
                }
                Button(action: onLibrary) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            } label: {
                Image(systemName: "photo.badge.plus")
            }

            if let dismiss = onDismissKeyboard {
                Spacer(minLength: 2)
                Button(action: dismiss) {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .buttonStyle(.plain)
            }
        }
        .font(.subheadline)
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

// MARK: - Rich content renderer

/// Renders a content string: rich JSON via `RichTextRenderer`, otherwise the
/// legacy Markdown path via `MarkdownText`.
struct RichContentView: View {
    let text: String

    var body: some View {
        if RichText.isRich(text) {
            RichTextRenderer(text: text)
        } else {
            MarkdownText(markdown: text)
        }
    }
}

struct RichTextRenderer: View {
    let text: String

    private var runs: [[String: Any]] { RichText.runs(from: text) }

    private struct RenderItem {
        var textView: Text?
        let imageData: Data?
        var isImage: Bool { imageData != nil }
    }

    private var groupedItems: [RenderItem] {
        var items: [RenderItem] = []
        for run in runs {
            if (run["type"] as? String) == "image" {
                let data = (run["data"] as? String).flatMap { Data(base64Encoded: $0) }
                items.append(RenderItem(textView: nil, imageData: data))
            } else {
                guard let view = textView(for: run) else { continue }
                if var last = items.last, !last.isImage, let lastView = last.textView {
                    last.textView = lastView + view
                    items[items.count - 1] = last
                } else {
                    items.append(RenderItem(textView: view, imageData: nil))
                }
            }
        }
        return items
    }

    private func textView(for run: [String: Any]) -> Text? {
        guard let s = run["s"] as? String, !s.isEmpty else { return nil }
        var t = Text(s)
        if let size = (run["size"] as? NSNumber)?.doubleValue {
            t = t.font(.system(size: CGFloat(size)))
        }
        if (run["b"] as? Bool) == true { t = t.bold() }
        if (run["i"] as? Bool) == true { t = t.italic() }
        if (run["u"] as? Bool) == true { t = t.underline() }
        if let c = run["c"] as? String { t = t.foregroundColor(Color(hex: c)) }
        return t
    }

    var body: some View {
        let items = groupedItems
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if let view = item.textView {
                        view
                    }
                }
            }
        }
    }
}
