import Foundation
import SwiftData

enum ExpressionCategory: String, CaseIterable, Codable {
    case causality   = "因果论证"
    case comparison  = "对比分析"
    case emphasis    = "递进强调"
    case transition  = "过渡衔接"
    case example     = "举例说明"
    case opening     = "开场破题"
    case closing     = "总结收尾"
    case answer408   = "专业答题"
    case custom      = "自定义"

    var icon: String {
        switch self {
        case .causality:   return "arrow.triangle.branch"
        case .comparison:  return "arrow.left.arrow.right"
        case .emphasis:    return "exclamationmark.bubble"
        case .transition:  return "arrow.turn.down.right"
        case .example:     return "lightbulb.max"
        case .opening:     return "play.fill"
        case .closing:     return "stop.fill"
        case .answer408:   return "cpu.fill"
        case .custom:      return "tag"
        }
    }

    var color: String {
        switch self {
        case .causality:   return "#FF6B6B"
        case .comparison:  return "#4ECDC4"
        case .emphasis:    return "#FF8E53"
        case .transition:  return "#6C5CE7"
        case .example:     return "#FECA57"
        case .opening:     return "#48DBFB"
        case .closing:     return "#FF9FF3"
        case .answer408:   return "#00B4D8"
        case .custom:      return "#B0B0B0"
        }
    }
}

@Model
final class Expression {
    var text: String
    var categoryValue: String       // ExpressionCategory.rawValue
    var source: String              // 出处
    var usageScene: String          // 适用场景说明
    var notes: String               // 个人笔记
    var isFavorite: Bool
    var isPreset: Bool              // 预设句子不可删除
    var createdAt: Date

    var category: ExpressionCategory {
        ExpressionCategory(rawValue: categoryValue) ?? .custom
    }

    init(
        text: String,
        category: ExpressionCategory = .custom,
        source: String = "",
        usageScene: String = "",
        notes: String = "",
        isFavorite: Bool = false,
        isPreset: Bool = false
    ) {
        self.text = text
        self.categoryValue = category.rawValue
        self.source = source
        self.usageScene = usageScene
        self.notes = notes
        self.isFavorite = isFavorite
        self.isPreset = isPreset
        self.createdAt = Date()
    }

    /// 预设句子库
    static let presets: [(String, ExpressionCategory, String)] = [
        // 因果论证
        ("究其原因在于，多个因素共同作用导致了这一结果。", .causality, "分析问题根源时使用，将现象引导至深层原因"),
        ("正是由于……才导致……，因此解决问题的关键在于……", .causality, "建立因果链，适用于论证类表达"),
        ("从本质上讲，这一现象折射出的是……问题。", .causality, "由表及里，将具体问题上升到本质层面"),
        ("短期来看……但长远而言……", .causality, "区分短期和长期效应，适用于复杂问题分析"),
        ("之所以出现这种情况，根源在于……", .causality, "直接指出根本原因，简洁有力"),

        // 对比分析
        ("从另一个角度来看，这个问题的另一面是……", .comparison, "展现全面思考能力，避免观点片面"),
        ("相较于……而言，这种做法的优势在于……", .comparison, "用于比较两种方案或观点时"),
        ("表面上看……但实际上……", .comparison, "揭示表象与实质的差异"),
        ("虽然……但是……更重要的是……", .comparison, "转折后的重心转移，使表达更有层次"),
        ("与……不同的是，这个方案……", .comparison, "突出差异点，适用于对比分析"),

        // 递进强调
        ("不仅如此，更关键的是……", .emphasis, "将讨论推向更深层次，强调核心要点"),
        ("尤为值得关注的是……", .emphasis, "吸引注意力到最重要的论点上"),
        ("这一点尤其重要，因为它直接关系到……", .emphasis, "解释重要性的原因，增强说服力"),
        ("更进一步说，这意味着……", .emphasis, "推导延伸结论，展现思维深度"),
        ("归根结底，最核心的问题是……", .emphasis, "排除干扰，聚焦最本质的问题"),

        // 过渡衔接
        ("接下来我们从……的视角来审视这个问题。", .transition, "切换到新的分析角度"),
        ("这引出了一个更深层的问题……", .transition, "自然过渡到更深层次的讨论"),
        ("在讨论……之前，我们需要先厘清……", .transition, "铺垫过渡，确保逻辑顺畅"),
        ("以上分析为我们揭示了……接下来聚焦……", .transition, "总结上文并引出下文"),
        ("这并不意味着……恰恰相反……", .transition, "纠正可能的误解，引出正确的理解"),

        // 举例说明
        ("以……为例便可见一斑。", .example, "用具体事例支撑抽象观点"),
        ("……恰恰印证了这一点。", .example, "将例子与论点紧密关联"),
        ("现实生活中不乏这样的例子……", .example, "引入生活中的案例，增强共鸣"),
        ("最能说明问题的是……", .example, "引入最典型的例子"),
        ("……就是一个很好的佐证。", .example, "简洁地引用例证"),

        // 开场破题
        ("今天我想和大家探讨的话题是……", .opening, "直接切入主题，适合正式场合"),
        ("在开始之前，先给大家分享一个数据/故事……", .opening, "用数据或故事吸引注意力"),
        ("我相信在座的各位都曾经历过……", .opening, "建立共鸣，拉近与听众的距离"),
        ("有一个问题值得我们深思……", .opening, "抛出一个引人思考的问题"),
        ("简单来说，我想表达的核心观点是……", .opening, "开门见山，适合时间有限的场合"),

        // 总结收尾
        ("综上所述，我们可以看到……", .closing, "全面总结，适用于正式总结"),
        ("最后，我想强调的是……", .closing, "收尾前强调最核心的信息"),
        ("回顾今天的讨论，最重要的收获是……", .closing, "回顾式总结，强化记忆点"),
        ("这给我们带来的启示是……", .closing, "升华主题，给出行动指引"),
        ("用一个词来概括就是……", .closing, "简洁有力的收尾方式"),

        // 专业答题（408）
        ("该硬件的工作流程可以概括为以下几个阶段：首先……其次……接着……最后……", .answer408, "描述硬件工作流程的标准结构，适用于计组/OS的流程题"),
        ("……的核心功能是……，具体而言，它通过……机制实现了……", .answer408, "解释某个组件或机制的作用，先定义核心功能再展开实现细节"),
        ("从层次结构来看，……位于……层，负责……，向上为……提供……接口，向下调用……的服务。", .answer408, "分层描述架构中某层的位置和职责，适用于OS/网络的层次结构分析"),
        ("……和……的相同点在于……不同点主要体现在以下几个方面：第一……第二……第三……", .answer408, "对比两个概念的异同，适用于所有408科目的概念辨析题"),
        ("该算法的基本思想是……其执行过程可以描述为：初始化……迭代/递归地处理……最终得到……", .answer408, "描述算法的思想和执行流程，适用于数据结构中的算法题"),
        ("……之所以采用这种设计，是因为它需要在……和……之间取得平衡。具体来说……", .answer408, "分析设计动机和权衡，适用于计组/OS中的设计决策题"),
        ("从时间复杂度的角度分析，该算法的时间复杂度为O(……)，其中……是……。这是因为……", .answer408, "复杂度和性能分析的标准表述，适用于所有需要性能分析的题目"),
        ("举一个具体的例子来说明：假设我们有一个……，当……时，系统会……", .answer408, "用具体例子辅助说明抽象概念，适用于所有需要举例说明的知识点"),
        ("……机制解决了……问题。在没有该机制的情况下，会出现……的问题，引入后则……", .answer408, "问题-解决方案的论述结构，适用于描述某项技术或机制的引入原因"),
        ("总结而言，……的核心要点有三：一是……二是……三是……", .answer408, "总结型表述，常用于回顾多个知识点的关联或一个知识点的若干关键结论"),
    ]
}
