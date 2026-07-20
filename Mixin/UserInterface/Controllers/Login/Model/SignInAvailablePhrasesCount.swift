import Foundation
import MixinServices

protocol SignInAvailablePhrasesCount: CaseIterable, RawRepresentable where RawValue == Int { }

extension MixinMnemonics.PhrasesCount: SignInAvailablePhrasesCount { }
extension BIP39Mnemonics.PhrasesCount: SignInAvailablePhrasesCount { }
