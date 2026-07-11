import Foundation

@main
private enum CharacterSetPerformanceTests {
    static func main() {
        for character in SplitFlapCharacter.drumCharacters {
            let successor = character.idleSuccessor
            precondition(
                character.stepsTo(successor) == 1,
                "Idle drift must encode exactly one mechanical step for \(character.displayString)"
            )
        }

        let unicode = SplitFlapCharacter("🚆")
        precondition(unicode.idleSuccessor == .space)
        precondition(unicode.stepsTo(unicode.idleSuccessor) == 1)
    }
}
