import XCTest
@testable import MnemoOrchestrator

final class CommandParserTests: XCTestCase {
    func testPlainTextIsAQuery() {
        XCTAssertEqual(CommandParser.parse("what is my build tool?"), .query("what is my build tool?"))
    }

    func testHelpAndInspectAndClear() {
        XCTAssertEqual(CommandParser.parse("/help"), .command(.help))
        XCTAssertEqual(CommandParser.parse("/inspect"), .command(.inspect))
        XCTAssertEqual(CommandParser.parse("/profile"), .command(.profile))
        XCTAssertEqual(CommandParser.parse("/clear"), .command(.clear))
    }

    func testForgetCarriesTheFactText() {
        XCTAssertEqual(CommandParser.parse("/forget I have a boat named Serenity"),
                       .command(.forget("I have a boat named Serenity")))
        // No argument → treated as help (nothing to forget).
        XCTAssertEqual(CommandParser.parse("/forget"), .command(.help))
    }

    func testScopeCarriesContainer() {
        XCTAssertEqual(CommandParser.parse("/scope work"), .command(.scope("work")))
        XCTAssertEqual(CommandParser.parse("/scope   personal  "), .command(.scope("personal")))
    }

    func testLeadingWhitespaceAndCaseTolerant() {
        XCTAssertEqual(CommandParser.parse("  /HELP "), .command(.help))
        XCTAssertEqual(CommandParser.parse("/Forget X"), .command(.forget("X")))
    }

    func testUnknownCommandFallsBackToHelp() {
        XCTAssertEqual(CommandParser.parse("/wat"), .command(.help))
    }

    func testBareSlashIsQuery() {
        // A lone "/" or text that merely contains a slash is a normal query.
        XCTAssertEqual(CommandParser.parse("and/or which is better?"), .query("and/or which is better?"))
    }

    func testHelpTextListsCommands() {
        let help = CommandParser.helpText
        for token in ["/help", "/forget", "/scope", "/inspect", "/profile", "/clear"] {
            XCTAssertTrue(help.contains(token), "help text missing \(token)")
        }
    }
}
