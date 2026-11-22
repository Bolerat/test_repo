// 同窝 Covey · UI 测试（XCUITest）
// 运行前先启动 Mock AI 服务：python3 ios/tools/mock_ai_server.py
import XCTest

final class CoveyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--covey-uitest-reset"]
        app.launch()
    }

    // MARK: - 工具

    private func tapTab(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let tabButton = app.tabBars.buttons[name]
        if tabButton.waitForExistence(timeout: 5) {
            tabButton.tap()
            return
        }
        let button = app.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "找不到标签页：\(name)", file: file, line: line)
        button.tap()
    }

    private func field(containing placeholder: String) -> XCUIElement {
        let pred = NSPredicate(format: "placeholderValue CONTAINS %@", placeholder)
        let textView = app.textViews.matching(pred).firstMatch
        if textView.exists { return textView }
        return app.textFields.matching(pred).firstMatch
    }

    /// 全选后输入并校验（要求完全相等，防止追加到旧值后面），必要时重试
    private func replaceText(_ element: XCUIElement, with text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "找不到输入框", file: file, line: line)
        for _ in 0..<3 {
            element.tap()
            app.typeKey("a", modifierFlags: .command)
            element.typeText(text)
            let current = (element.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if current == text { return }
        }
        XCTFail("输入框内容替换失败", file: file, line: line)
    }

    private func labeledStaticText(_ keyword: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", keyword)).firstMatch
    }

    private func dismissKeyboard() {
        guard app.keyboards.firstMatch.waitForExistence(timeout: 2) else { return }
        let returnKey = app.keyboards.buttons["return"]
        if returnKey.exists { returnKey.tap() }
    }

    // MARK: - 记一笔 & 手账

    func testNoteEntryAndJournal() {
        XCTAssertTrue(app.staticTexts["布丁的日常"].waitForExistence(timeout: 10))

        app.buttons["记一笔"].tap()
        let noteField = field(containing: "今天发生了什么？")
        XCTAssertTrue(noteField.waitForExistence(timeout: 5))
        noteField.tap()
        noteField.typeText("早上喂了半碗猫粮，布丁吃得很香")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["记一笔"].waitForExistence(timeout: 5))

        // 今日页「最新记录」出现，连续记录徽章变为 1
        let noteText = "早上喂了半碗猫粮，布丁吃得很香"
        XCTAssertTrue(app.staticTexts[noteText].waitForExistence(timeout: 5))
        XCTAssertTrue(labeledStaticText("连续记录 1 天").exists)

        tapTab("记录")
        XCTAssertTrue(app.staticTexts["记录手账"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["今天"].exists)
        XCTAssertTrue(app.staticTexts[noteText].exists)

        // 分类筛选
        app.buttons["花费"].tap()
        XCTAssertTrue(app.staticTexts["这个分类还没有记录"].waitForExistence(timeout: 5))
        app.buttons["日常"].tap()
        XCTAssertTrue(app.staticTexts[noteText].waitForExistence(timeout: 5))

        // 搜索
        let search = field(containing: "搜索记录内容")
        search.tap()
        search.typeText("猫粮")
        XCTAssertTrue(app.staticTexts[noteText].waitForExistence(timeout: 5))
        replaceText(search, with: "xyz-not-exist")
        XCTAssertTrue(app.staticTexts["没有匹配的记录"].waitForExistence(timeout: 5))
    }

    // MARK: - 照护提醒

    func testReminderCreation() {
        XCTAssertTrue(app.staticTexts["布丁的日常"].waitForExistence(timeout: 10))

        app.buttons["+ 新建"].tap()
        let titleField = field(containing: "事项（例如：猫三联疫苗加强）")
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("布丁疫苗加强")
        app.buttons["保存"].tap()

        XCTAssertTrue(app.staticTexts["布丁疫苗加强"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["疫苗"].exists)
    }

    // MARK: - 宠物档案与体重

    func testPetProfileAndWeight() {
        tapTab("宠物")
        XCTAssertTrue(app.staticTexts["布丁"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["基本信息"].exists)
        XCTAssertTrue(app.staticTexts["家庭成员"].exists)

        app.buttons["+ 记录"].tap()
        let kgField = field(containing: "体重（kg）")
        XCTAssertTrue(kgField.waitForExistence(timeout: 5))
        kgField.tap()
        kgField.typeText("4.2")
        app.buttons["保存"].tap()

        XCTAssertTrue(labeledStaticText("4.2 kg").waitForExistence(timeout: 5))
        XCTAssertTrue(labeledStaticText("当前体重").exists)
    }

    // MARK: - 设置页与 AI 配置（需要 mock 服务在 8799 端口）

    func testSettingsAndAIConfiguration() {
        tapTab("我的")
        XCTAssertTrue(app.staticTexts["设置"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["AI 助手"].exists)
        XCTAssertTrue(app.staticTexts["提醒"].exists)
        XCTAssertTrue(app.staticTexts["宠物与亲友"].exists)
        XCTAssertTrue(app.staticTexts["Pawly 的记忆"].exists)
        XCTAssertTrue(app.staticTexts["数据与隐私"].exists)

        let baseField = field(containing: "https://api.example.com/v1")
        replaceText(baseField, with: "http://localhost:8799/v1")

        let keyField = app.secureTextFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS %@", "sk-")
        ).firstMatch
        XCTAssertTrue(keyField.waitForExistence(timeout: 5))
        keyField.tap()
        keyField.typeText("mock-api-key")

        let modelField = field(containing: "gpt-4o-mini")
        replaceText(modelField, with: "mock-model")
        dismissKeyboard()

        app.buttons["测试连接"].tap()
        let success = labeledStaticText("连接成功")
        XCTAssertTrue(success.waitForExistence(timeout: 15), "Mock AI 连接测试应成功")

        app.buttons["保存"].tap()
        XCTAssertTrue(labeledStaticText("已保存").waitForExistence(timeout: 5))

        tapTab("AI 助手")
        XCTAssertTrue(app.staticTexts["AI 助手 Pawly"].waitForExistence(timeout: 10))

        app.buttons["总结我家宠物最近一周的状态"].tap()
        let reply = labeledStaticText("Pawly mock 回复")
        XCTAssertTrue(reply.waitForExistence(timeout: 15), "应收到 Mock AI 的回复")
    }
}
