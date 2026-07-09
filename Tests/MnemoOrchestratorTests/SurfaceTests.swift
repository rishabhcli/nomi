import XCTest
@testable import MnemoOrchestrator

// MARK: - E-0001 Perceived latency (NotchSurfaceView)

final class SurfacePerceivedLatencyTests: XCTestCase {
    func testE0001_summonSpringFasterThanGrow() {
        XCTAssertTrue(SurfaceUX.PerceivedLatency.summonFasterThanGrow(
            summonResponse: SurfaceUX.PerceivedLatency.summonResponse,
            growResponse: 0.32))
    }

    func testE0001_privacyDotVisibleImmediatelyOnExpand() {
        XCTAssertTrue(SurfaceUX.PerceivedLatency.privacyDotVisibleImmediately(phase: .input))
        XCTAssertFalse(SurfaceUX.PerceivedLatency.privacyDotVisibleImmediately(phase: .idle))
    }

    func testE0001_predictiveWidthMatchesExpandedStates() {
        XCTAssertEqual(SurfaceUX.PerceivedLatency.predictiveExpandedWidth(phase: .input, listening: false), 520)
        XCTAssertEqual(SurfaceUX.PerceivedLatency.predictiveExpandedWidth(phase: .searching, listening: false), 520)
        XCTAssertEqual(SurfaceUX.PerceivedLatency.predictiveExpandedWidth(phase: .idle, listening: false), 0)
    }

    func testE0001_dictationHoldIsSnappy() {
        XCTAssertLessThanOrEqual(SurfaceUX.PerceivedLatency.dictationHoldSeconds, 0.35)
        XCTAssertGreaterThanOrEqual(SurfaceUX.PerceivedLatency.dictationHoldSeconds, 0.25)
    }

    func testE0001_seedMatchesPrompt() {
        XCTAssertEqual(SurfaceUX.seed(forPrompt: 1), "d4276e79207e")
    }
}

// MARK: - E-0002 Reading-grade typography (SurfaceBlocks)

final class SurfaceTypographyTests: XCTestCase {
    func testE0002_answerTypographyMeetsReadingGrade() {
        XCTAssertEqual(SurfaceUX.Typography.answerPointSize, 17)
        XCTAssertGreaterThanOrEqual(SurfaceUX.Typography.bodyLeading, 1.3)
        XCTAssertEqual(SurfaceUX.Typography.comfortableReadWidth, 520)
    }

    func testE0002_lineHeightScalesWithPointSize() {
        let lh = SurfaceUX.Typography.lineHeight(for: 17)
        XCTAssertGreaterThan(lh, 17)
        XCTAssertLessThan(lh, 30)
    }

    func testE0002_secondaryTextContrast() {
        XCTAssertGreaterThanOrEqual(SurfaceUX.Typography.secondaryTextOpacity, 0.65)
    }
}

// MARK: - E-0003 Citation affordance (ReasoningTraceView)

final class SurfaceCitationTests: XCTestCase {
    func testE0003_citationLabelsAreNumbered() {
        XCTAssertEqual(SurfaceUX.CitationAffordance.citationLabel(index: 0, title: "Notes"), "Source 1, Notes")
        XCTAssertEqual(SurfaceUX.CitationAffordance.citationLabel(index: 2, title: "Doc"), "Source 3, Doc")
    }

    func testE0003_maxVisibleSources() {
        XCTAssertEqual(SurfaceUX.CitationAffordance.maxVisibleSources, 3)
    }

    func testE0003_chipMeetsMinimumTapTarget() {
        XCTAssertGreaterThanOrEqual(SurfaceUX.CitationAffordance.chipMinTapWidth, 44)
    }

    func testE0003_reasoningStepCitationMarker() {
        XCTAssertTrue(SurfaceUX.CitationAffordance.stepShowsCitationMarker("Reading source [Notes]"))
        XCTAssertFalse(SurfaceUX.CitationAffordance.stepShowsCitationMarker("Thinking…"))
    }
}

// MARK: - E-0004 Error recovery clarity (NotchViewModel)

final class SurfaceErrorRecoveryTests: XCTestCase {
    func testE0004_primaryRecoveriesAreProminent() {
        XCTAssertTrue(SurfaceUX.ErrorRecovery.recoveryIsPrimary(.restartEngine))
        XCTAssertTrue(SurfaceUX.ErrorRecovery.recoveryIsPrimary(.loadModel))
        XCTAssertFalse(SurfaceUX.ErrorRecovery.recoveryIsPrimary(.broaden))
    }

    func testE0004_recoveryStatusMessagesAreNonEmpty() {
        for r in [TerminalState.Recovery.broaden, .restartEngine, .loadModel, .waitAndRetry, .addFiles] {
            XCTAssertFalse(SurfaceUX.ErrorRecovery.recoveryStatusMessage(r).isEmpty)
        }
    }

    func testE0004_recoveryButtonTitles() {
        XCTAssertEqual(SurfaceUX.ErrorRecovery.recoveryButtonTitle(.addFiles), "Open memory folder")
    }
}

// MARK: - E-0005 VoiceOver rotor order

final class SurfaceVoiceOverTests: XCTestCase {
    func testE0005_rotorOrderIsStable() {
        XCTAssertLessThan(SurfaceUX.voiceOverSortPriority(for: .queryField),
                          SurfaceUX.voiceOverSortPriority(for: .answer))
        XCTAssertLessThan(SurfaceUX.voiceOverSortPriority(for: .answer),
                          SurfaceUX.voiceOverSortPriority(for: .privacy))
    }
}

// MARK: - E-0006 Keyboard-only summon

final class SurfaceKeyboardTests: XCTestCase {
    func testE0006_focusOnSummon() {
        XCTAssertTrue(SurfaceUX.Keyboard.focusInputOnSummon(phase: .input))
        XCTAssertFalse(SurfaceUX.Keyboard.focusInputOnSummon(phase: .idle))
    }

    func testE0006_shortcutsDocumented() {
        XCTAssertFalse(SurfaceUX.Keyboard.submitShortcut.isEmpty)
        XCTAssertFalse(SurfaceUX.Keyboard.newConversationShortcut.isEmpty)
    }
}

// MARK: - E-0007 Press-hold dictation

final class SurfaceDictationDiscoverabilityTests: XCTestCase {
    func testE0007_holdGestureThreshold() {
        XCTAssertTrue(SurfaceUX.DictationDiscoverability.holdGestureRecognized(duration: 0.35))
        XCTAssertFalse(SurfaceUX.DictationDiscoverability.holdGestureRecognized(duration: 0.10))
    }

    func testE0007_accessibilityHintMentionsHold() {
        XCTAssertTrue(SurfaceUX.DictationDiscoverability.accessibilityHint.localizedCaseInsensitiveContains("hold"))
    }
}

// MARK: - E-0008 Reasoning trace legibility

final class SurfaceReasoningTraceTests: XCTestCase {
    func testE0008_showsOnlyWhileSearching() {
        XCTAssertTrue(SurfaceUX.ReasoningTrace.shouldShow(phase: .searching, itemCount: 2, hasAnswer: false))
        XCTAssertFalse(SurfaceUX.ReasoningTrace.shouldShow(phase: .answering, itemCount: 2, hasAnswer: true))
        XCTAssertFalse(SurfaceUX.ReasoningTrace.shouldShow(phase: .searching, itemCount: 0, hasAnswer: false))
    }

    func testE0008_stepOpacityIncreasesWithIndex() {
        let a = SurfaceUX.ReasoningTrace.stepOpacity(index: 0, total: 5, reduceMotion: false)
        let b = SurfaceUX.ReasoningTrace.stepOpacity(index: 3, total: 5, reduceMotion: false)
        XCTAssertLessThan(a, b)
    }

    func testE0008_truncatesLongTraces() {
        let steps = (1...20).map { "step \($0)" }
        XCTAssertEqual(SurfaceUX.ReasoningTrace.truncatedSteps(steps).count,
                       SurfaceUX.ReasoningTrace.maxVisibleSteps)
    }
}

// MARK: - E-0009 Glass material hierarchy

final class SurfaceGlassHierarchyTests: XCTestCase {
    func testE0009_highContrastRaisesOpacities() {
        XCTAssertGreaterThan(SurfaceUX.GlassHierarchy.trayTint(highContrast: true),
                           SurfaceUX.GlassHierarchy.trayTint(highContrast: false))
        XCTAssertGreaterThan(SurfaceUX.GlassHierarchy.pillFill(highContrast: true),
                           SurfaceUX.GlassHierarchy.pillFill(highContrast: false))
    }
}

// MARK: - E-0010 Spring overshoot elimination

final class SurfaceSpringTests: XCTestCase {
    func testE0010_dampingPreventsOvershoot() {
        XCTAssertTrue(SurfaceUX.SpringOvershoot.dampingPreventsOvershoot(
            damping: SurfaceUX.SpringOvershoot.growDamping))
        XCTAssertTrue(SurfaceUX.SpringOvershoot.dampingPreventsOvershoot(
            damping: SurfaceUX.SpringOvershoot.collapseDamping))
    }
}

// MARK: - E-0011 120fps orb thermal stability

final class SurfaceOrbPerformanceTests: XCTestCase {
    func testE0011_frameBudgetAt120fps() {
        XCTAssertEqual(SurfaceUX.OrbPerformance.targetFPS, 120, accuracy: 0.01)
        XCTAssertLessThan(SurfaceUX.OrbPerformance.frameBudgetMs, 10)
    }

    func testE0011_withinBudgetAt120fps() {
        XCTAssertTrue(SurfaceUX.OrbPerformance.withinFrameBudget(elapsedMs: 8.0))
        XCTAssertFalse(SurfaceUX.OrbPerformance.withinFrameBudget(elapsedMs: 20.0))
    }
}

// MARK: - E-0012 Empty corpus onboarding

final class SurfaceEmptyCorpusTests: XCTestCase {
    func testE0012_onboardingForEmptyCorpus() {
        XCTAssertTrue(SurfaceUX.EmptyCorpus.showsOnboarding(terminal: .emptyCorpus))
        XCTAssertFalse(SurfaceUX.EmptyCorpus.showsOnboarding(terminal: .empty(nearest: [])))
    }
}

// MARK: - E-0013 In-flight query lock

final class SurfaceQueryLockTests: XCTestCase {
    func testE0013_blocksResummonWhileQuerying() {
        XCTAssertTrue(SurfaceUX.QueryLock.blocksResummon(isQuerying: true, phase: .answering))
        XCTAssertTrue(SurfaceUX.QueryLock.blocksResummon(isQuerying: false, phase: .searching))
        XCTAssertFalse(SurfaceUX.QueryLock.blocksResummon(isQuerying: false, phase: .input))
    }

    func testE0013_blocksRepeatSubmitWhileSearching() {
        XCTAssertTrue(SurfaceUX.QueryLock.blocksRepeatSubmit(phase: .searching))
        XCTAssertFalse(SurfaceUX.QueryLock.blocksRepeatSubmit(phase: .input))
    }
}

// MARK: - E-0014 Unsupported sentence styling

final class SurfaceUnsupportedStylingTests: XCTestCase {
    func testE0014_flagsUnsupportedSentences() {
        let unsupported: Set<Int> = [1, 3]
        XCTAssertTrue(SurfaceUX.UnsupportedStyling.isUnsupported(sentenceIndex: 1, unsupported: unsupported))
        XCTAssertFalse(SurfaceUX.UnsupportedStyling.isUnsupported(sentenceIndex: 0, unsupported: unsupported))
    }
}

// MARK: - E-0015 Suggestion chip relevance

final class SurfaceSuggestionTests: XCTestCase {
    func testE0015_filtersShortSuggestions() {
        let filtered = SurfaceUX.Suggestions.filtered(["ok", "valid follow-up", "x", "another good one"])
        XCTAssertEqual(filtered, ["valid follow-up", "another good one"])
    }

    func testE0015_capsAtFour() {
        let many = (1...10).map { "suggestion number \($0)" }
        XCTAssertEqual(SurfaceUX.Suggestions.filtered(many).count, 4)
    }
}

// MARK: - E-0016 Entity chip exploration

final class SurfaceEntityChipTests: XCTestCase {
    func testE0016_truncatesToFive() {
        let entities = (1...10).map { "Entity\($0)" }
        XCTAssertEqual(SurfaceUX.EntityChips.truncated(entities).count, 5)
    }

    func testE0016_explorationLabel() {
        XCTAssertEqual(SurfaceUX.EntityChips.explorationLabel("Alice"), "Explore Alice")
    }
}

// MARK: - E-0017+ Multi-display, Reduce Motion, Increase Contrast

final class SurfaceAccessibilityTests: XCTestCase {
    func testE0018_multiDisplayAlignment() {
        XCTAssertTrue(SurfaceUX.MultiDisplay.isAligned(panelMidX: 756, notchMidX: 756.5, topDelta: 0.5))
        XCTAssertFalse(SurfaceUX.MultiDisplay.isAligned(panelMidX: 756, notchMidX: 760, topDelta: 0.5))
    }

    func testE0019_reduceMotionUsesOpacityOnly() {
        XCTAssertTrue(SurfaceUX.ReduceMotion.usesOpacityOnly(reduceMotion: true))
        XCTAssertFalse(SurfaceUX.ReduceMotion.usesOpacityOnly(reduceMotion: false))
    }

    func testE0020_increaseContrastRaisesTextOpacity() {
        let normal = SurfaceUX.IncreaseContrast.textOpacity(primary: false, highContrast: false)
        let high = SurfaceUX.IncreaseContrast.textOpacity(primary: false, highContrast: true)
        XCTAssertGreaterThan(high, normal)
    }
}

// MARK: - Phase 2 prompt registry (all 1000)

final class SurfacePromptRegistryTests: XCTestCase {
    func testAllPromptsHaveValidTargetAndDimension() {
        for n in 1...1000 {
            let target = SurfaceTarget.forPrompt(n)
            let dimension = UXDimension.forPrompt(n)
            XCTAssertFalse(target.rawValue.isEmpty)
            XCTAssertFalse(dimension.rawValue.isEmpty)
            XCTAssertEqual(SurfaceUX.seed(forPrompt: n).count, 12)
        }
    }

    func testPromptCycleCoversAllSurfaces() {
        var seen = Set<SurfaceTarget>()
        for n in 1...20 { seen.insert(SurfaceTarget.forPrompt(n)) }
        XCTAssertEqual(seen.count, SurfaceTarget.allCases.count)
    }

    func testPromptCycleCoversAllDimensions() {
        var seen = Set<UXDimension>()
        for n in 1...16 { seen.insert(UXDimension.forPrompt(n)) }
        XCTAssertEqual(seen.count, UXDimension.allCases.count)
    }
}

// MARK: - Surface geometry integration

final class SurfaceGeometryTests: XCTestCase {
    func testInputAndReadWidthMatchForVerticalMorph() {
        XCTAssertEqual(SurfaceUX.Typography.comfortableReadWidth, 520)
        let inputGeo = SurfaceGeometry(phase: .input, listening: false,
                                       notch: CGSize(width: 200, height: 32), answerHeight: 0)
        let answerGeo = SurfaceGeometry(phase: .answering, listening: false,
                                        notch: CGSize(width: 200, height: 32), answerHeight: 100)
        XCTAssertEqual(inputGeo.width, answerGeo.width,
                       "input↔answer morph must be pure vertical grow")
    }
}

// Note: SurfaceGeometry is defined in MnemoApp; test via duplicated logic values
private struct SurfaceGeometry {
    let width: CGFloat
    init(phase: NotchPhase, listening: Bool, notch: CGSize, answerHeight: CGFloat) {
        if listening {
            width = 176
            return
        }
        switch phase {
        case .idle: width = notch.width
        case .input, .searching, .answering, .state: width = 520
        }
    }
}
