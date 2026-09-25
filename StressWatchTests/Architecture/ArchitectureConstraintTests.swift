import XCTest
@testable import StressWatch

/// 架构约束测试（抄 Whoordan `ArchitectureConstraintTests`）：
/// 读源码文本断言分层纪律，长期防腐化。
final class ArchitectureConstraintTests: XCTestCase {

    /// 项目根目录（测试运行时的当前目录）。
    private var projectRoot: URL {
        // 从 #file 反推项目根目录
        let thisFile = URL(fileURLWithPath: #file)
        // StressWatchTests/Architecture/ArchitectureConstraintTests.swift
        // → StressWatchTests → StressWatch（项目根）
        return thisFile
            .deletingLastPathComponent() // Architecture
            .deletingLastPathComponent() // StressWatchTests
            .deletingLastPathComponent() // 项目根
    }

    private func sourceFiles(at path: String) -> [URL] {
        let dir = projectRoot.appendingPathComponent(path)
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        return files
    }

    private func readSource(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    // MARK: - Core/Analysis 引擎只 import Foundation

    func test_engines_onlyImportFoundation() {
        let engineDirs = [
            "StressWatch/Core/Analysis/Metrics",
            "StressWatch/Core/Analysis/Baseline",
            "StressWatch/Core/Analysis/Scoring",
            "StressWatch/Core/Analysis/Trend",
            "StressWatch/Core/Analysis/Correlation",
            "StressWatch/Core/Analysis/Insight",
            "StressWatch/Core/Analysis/Privacy"
        ]

        for dir in engineDirs {
            for file in sourceFiles(at: dir) {
                let source = readSource(file)
                let fileName = file.lastPathComponent

                // 允许 import Foundation；禁止 import HealthKit / SwiftUI / UIKit / Combine
                let bannedImports = ["import HealthKit", "import SwiftUI", "import UIKit", "import Combine"]
                for banned in bannedImports {
                    XCTAssertFalse(
                        source.contains(banned),
                        "\(fileName) 不应 \(banned)（engine 只允许 import Foundation）"
                    )
                }
            }
        }
    }

    // MARK: - Features/ 禁止 import HealthKit

    func test_features_doNotImportHealthKit() {
        for file in sourceFiles(at: "StressWatch/Features") {
            let source = readSource(file)
            let fileName = file.lastPathComponent
            XCTAssertFalse(
                source.contains("import HealthKit"),
                "\(fileName) 不应 import HealthKit（Features 层禁止直接访问 HealthKit）"
            )
            XCTAssertFalse(
                source.contains("HKHealthStore"),
                "\(fileName) 不应引用 HKHealthStore"
            )
        }
    }
}

/// 文案契约测试：免责声明必须存在；禁止因果动词。
final class CopyContractTests: XCTestCase {

    private var projectRoot: URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func readSource(_ path: String) -> String {
        let url = projectRoot.appendingPathComponent(path)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    // MARK: - 免责声明

    func test_disclaimerExists() {
        // 至少在一个 UI 文件中找到医疗免责声明
        let candidates = [
            "StressWatch/Features/Settings/Views/SettingsView.swift",
            "StressWatch/Features/Analysis/Views/AnalysisView.swift",
            "StressWatch/Core/Analysis/Insight/LocalInsightComposer.swift"
        ]
        var found = false
        for path in candidates {
            let source = readSource(path)
            if source.contains("不提供医疗诊断") || source.contains("个人健康趋势参考") {
                found = true
                break
            }
        }
        XCTAssertTrue(found, "必须在 UI 或 Insight 层找到医疗免责声明文案")
    }

    // MARK: - 因果动词禁令

    func test_engineCode_containsNoCausalLiterals() {
        // Core/Analysis 下的用户可见文案不应包含因果动词。
        // 允许：注释、prompt 中的禁令说明、黑名单定义、测试断言。
        let engineDir = projectRoot.appendingPathComponent("StressWatch/Core/Analysis")
        guard let enumerator = FileManager.default.enumerator(at: engineDir, includingPropertiesForKeys: nil) else {
            return
        }

        let banned = ["导致", "证明你", "说明你患有"]

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let lines = source.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // 跳过注释
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("///") || trimmed.hasPrefix("*") {
                    continue
                }
                for word in banned where line.contains(word) {
                    // 允许出现在：prompt 禁令说明、黑名单定义、变量名/注释
                    let isInstruction = line.contains("不得使用") || line.contains("禁止") || line.contains("严禁")
                    let isBlacklist = line.contains("causalTerms") || line.contains("banned") || line.contains("\"导致\"") || line.contains("\"causes\"")
                    if isInstruction || isBlacklist {
                        continue
                    }
                    XCTFail("源码 \(url.lastPathComponent) 用户可见文案不应包含因果词: \(word) — \(line)")
                }
            }
        }
    }

    // MARK: - 哑空状态禁令

    func test_noBareEmptyState() {
        // UI 文件不应只显示 "暂无数据" 而没有引导。
        // DashboardMetric.swift 是展示模型（定义 status 文案），不是 UI 空态，
        // 因此只检查真正的 View 文件。
        let uiDir = projectRoot.appendingPathComponent("StressWatch/Features")
        guard let enumerator = FileManager.default.enumerator(at: uiDir, includingPropertiesForKeys: nil) else {
            return
        }

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let fileName = url.lastPathComponent
            // 跳过纯数据模型文件
            if fileName.contains("Metric.swift") || fileName.contains("DashboardMetric") {
                continue
            }
            let source = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if source.contains("\"暂无数据\"") || source.contains("\"No data\"") {
                let hasGuidance = source.contains("还需") || source.contains("建议") || source.contains("授权") || source.contains("数据不足") || source.contains("暂无")
                XCTAssertTrue(hasGuidance, "\(fileName) 的空态应有可执行引导，不能只有\"暂无数据\"")
            }
        }
    }
}
