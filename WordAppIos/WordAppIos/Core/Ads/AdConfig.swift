import Foundation

/// AdMob kimlikleri.
///
/// Geliştirme sırasında Google'ın **test** reklam birimleri kullanılır. Gerçek
/// birimle test etmek (kendi reklamına bakmak/tıklamak) AdMob politikalarına
/// aykırıdır ve hesabın askıya alınmasına yol açabilir; bu yüzden ayrım
/// derleme yapılandırmasına bırakılmıştır.
enum AdConfig {

    /// Ödüllü reklam birimi kimliği.
    static var rewardedUnitID: String {
        #if DEBUG
        return testRewardedUnitID
        #else
        return "ca-app-pub-5049340562241701/2177355163"
        #endif
    }

    /// Uygulama kimliği — `Info.plist` içindeki `GADApplicationIdentifier` ile aynı olmalıdır.
    static let applicationID = "ca-app-pub-5049340562241701~8159764413"

    /// Google'ın herkese açık test birimi (ödüllü).
    static let testRewardedUnitID = "ca-app-pub-3940256099942544/1712485313"
}
