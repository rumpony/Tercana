import Foundation

/// Rewrites game slang and idioms into plain English before Apple's translation sees them.
///
/// Apple's on-device model can't be given context or taught new words, and it translates idioms word by
/// word ("Lose the cops" → "Polislere yenil"). Plain wording in, correct Turkish out.
/// Only used for English source text and only in front of Apple's engine; DeepL and Claude get the original.
enum PlainEnglish {
    /// Ordered: longer, more specific phrases first. Patterns are case-insensitive and match whole words.
    private static let rules: [(String, String)] = [
        // Chases and police
        (#"lose (the|those) (cops|police|feds|heat)"#, "escape from the police"),
        (#"lose (them|'em|him|her|the tail)"#, "escape from them"),
        (#"shake (them|'em|the cops|the tail)"#, "escape from them"),
        (#"(lay|lie) low( for a while)?"#, "hide for a while"),
        (#"the heat(?:'s| is) (all )?(over|on) (us|you|me)"#, "the police are chasing us"),
        (#"the heat"#, "the police"),
        (#"(the )?five-?o"#, "the police"),
        (#"the feds"#, "the federal police"),
        (#"(cops|police) are on (us|you|me)"#, "the police are chasing us"),
        (#"wanted level"#, "police search level"),
        // Violence
        (#"take (them|'em|him|her|it) out"#, "kill $1"),
        (#"take out (the|those|that|all)"#, "kill $1"),
        (#"(waste|ice|whack|smoke) (him|her|them|'em)"#, "kill $2"),
        (#"(he|she|they)(?:'s| is| are) toast"#, "$1 is finished"),
        (#"bite the dust"#, "die"),
        (#"pop (a )?cap in"#, "shoot"),
        (#"strapped"#, "armed"),
        (#"piece"# + #"(?= on (you|him|her|me))"#, "gun"),
        // Money and deals
        (#"good for the money"#, "going to pay"),
        (#"(a|the) score"#, "$1 robbery"),
        (#"(a|the) job(?= (tonight|tomorrow|went))"#, "$1 robbery"),
        (#"(\d+|\w+) (g|grand)\b"#, "$1 thousand dollars"),
        (#"a grand\b"#, "a thousand dollars"),
        (#"bucks\b"#, "dollars"),
        (#"dough\b"#, "money"),
        (#"the take\b"#, "the stolen money"),
        (#"split the take"#, "share the stolen money"),
        // Attitude
        (#"(you )?got my back"#, "will you protect me"),
        (#"i got your back"#, "I will protect you"),
        (#"don't sweat it"#, "don't worry"),
        (#"no sweat"#, "no problem"),
        (#"chill out"#, "calm down"),
        (#"chill\b"#, "calm down"),
        (#"screw (this|it) up"#, "ruin $1"),
        (#"screwed up"#, "ruined"),
        (#"mess (this|it) up"#, "ruin $1"),
        (#"(we|i|you)(?:'re| are| am) screwed"#, "$1 are in big trouble"),
        (#"cold-blooded"#, "ruthless"),
        (#"(that's|this is) some (.+?) shit"#, "$1 really $2"),
        (#"what the hell"#, "what"),
        (#"what the fuck"#, "what"),
        (#"hell yeah"#, "yes, absolutely"),
        (#"hell no"#, "absolutely not"),
        (#"you bet"#, "of course"),
        (#"my bad"#, "my mistake"),
        (#"for real\?"#, "really?"),
        (#"no way"#, "impossible"),
        (#"bail\b"#, "leave"),
        (#"let's roll"#, "let's go"),
        (#"hit the road"#, "leave"),
        (#"step on it"#, "drive faster"),
        (#"floor it"#, "drive faster"),
        (#"go,? go,? go"#, "hurry, hurry"),
        (#"ride\b(?=[.!?]|$)"#, "car"),
        (#"(my|your|his|her) ride"#, "$1 car"),
        (#"snitch(ed)?"#, "informer"),
        (#"rat(ted)? (me|us|you) out"#, "betrayed $2"),
        (#"set (me|us|you) up"#, "trapped $1"),
        (#"(a|the) setup"#, "$1 trap"),
        (#"homie"#, "friend"),
        (#"\bbro\b"#, "brother"),
        (#"\bdude\b"#, "man"),
        (#"\bbuddy\b"#, "friend"),
        // Contractions Apple stumbles on
        (#"\bain't\b"#, "am not"),
        (#"\bgonna\b"#, "going to"),
        (#"\bgotta\b"#, "have to"),
        (#"\bwanna\b"#, "want to"),
        (#"\bkinda\b"#, "kind of"),
        (#"\blemme\b"#, "let me"),
        (#"\bgimme\b"#, "give me"),
        (#"\by'all\b"#, "you all"),
        (#"\bya\b"#, "you"),
        (#"\b'em\b"#, "them"),
        (#"\bnothin'"#, "nothing"),
        (#"\b(\w+)in'\b"#, "$1ing"),
    ]

    private static let compiled: [(NSRegularExpression, String)] = rules.compactMap { pattern, template in
        guard let regex = try? NSRegularExpression(pattern: #"(?<![\w'])"# + pattern, options: [.caseInsensitive])
        else { return nil }
        return (regex, template)
    }

    static func rewrite(_ text: String) -> String {
        var result = text
        for (regex, template) in compiled {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: template)
        }
        // Keep a capital letter at the start of each sentence after a lower-case replacement.
        return capitalizeSentences(result)
    }

    private static func capitalizeSentences(_ text: String) -> String {
        var output = ""
        var capitalizeNext = true
        for character in text {
            if capitalizeNext, character.isLetter {
                output.append(contentsOf: character.uppercased())
                capitalizeNext = false
            } else {
                output.append(character)
            }
            if ".!?".contains(character) { capitalizeNext = true }
        }
        return output
    }
}
