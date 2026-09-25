import Foundation

/// 分析隐私门禁（Whoordan `PrivacyAccessGuard` 模式）。
///
/// 决定"能否将健康数据发送给 LLM"。集中化谓词，UI 绕过也会被拦。
enum AnalysisPrivacyGuard {

    /// 是否可以将健康数据发送给 LLM / 分析后端。
    ///
    /// 条件：
    /// 1. 用户启用了 AI 分析（`enableAIAnalysis`）
    /// 2. 已配置 MiniMax Key **或** 自建分析服务器（二者之一即可）
    /// 3. 用户同意（预留，当前与 enable 相同）
    /// 4. **数据源不是 demo**（演示数据不该上云）
    static func canSendHealthDataToLLM(
        enabled: Bool,
        hasKey: Bool = false,
        hasBackend: Bool = false,
        consent: Bool = true,
        dataSource: AppDataSource
    ) -> Bool {
        guard enabled, consent else { return false }
        guard hasKey || hasBackend else { return false }
        // T6.5：demo 数据源禁止发送
        guard dataSource != .demo else { return false }
        return true
    }

    /// 不可发送时的原因（UI 可直接展示）。
    static func denyReason(
        enabled: Bool,
        hasKey: Bool = false,
        hasBackend: Bool = false,
        consent: Bool = true,
        dataSource: AppDataSource
    ) -> String? {
        if !enabled { return "AI 分析未启用，请在设置中开启。" }
        if !hasKey && !hasBackend { return "未找到 API Key 或分析服务器地址，请在设置中填写。" }
        if !consent { return "需要同意后才能使用 AI 分析。" }
        if dataSource == .demo { return "演示数据不会发送到云端分析。请切换到 Apple Health 数据源。" }
        return nil
    }
}
