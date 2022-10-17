import Foundation

public struct TIPConfig: Decodable {
    
    public static let current = TIPConfig(
        commitments: [
            "5HYSNEcudZqucSo8tjVkkkuz6QiTQPSCjSxdGY9gZ1V3JKGtJ5bfZXS3QbB8AnBPLVrJQLEyJaucw4S6MmJhkwTpqCpTiovjiiaab4PUZsS8NBUBFharae9R3QUMR9ouPTgFxqmqMGGXSAqrRziSqneTcEkgLymx5oahxGfSeovgTN1FDgKiAt",
            "5Jr6mXiEF1xtR7jJ8o2923vsGcqnjnegK9eVybDfXCnFXKhRVaJDCMHvGuHLo92TWSuBVrwDxYM8nHDiqYVb7csPQHHTyPjrGMPZiPe3PFhBYpz5nsDeVxjknZ8C9fPYYi67qyBy4fy1T6U4itXQEzjCTBdtjw2TXrNKe5oYPvJWx3X6ZpygCi",
            "5JTnSpeBG9NyBAEkXL6KxFW3fYMhM4rgBqLMXynrBxHcshuQViedG2H4UumcdLZzMjkyyAdsGmEAf4MKiULmN93aaNvqCXiHH7MYnyvGp96s9bXs2M61HgH1KKZ4Tvk6yBfnVmvwmGVnnsQMd7fTky37VZGqn56SkQa7ANEz52Bwfs7uBBVZzV",
            "5JDXsF4qPcf9cwKuAL2H4scnaMEz3GYnyM3koVx5AE7rDvaLCeqWZ8ksXES9eQooKtfQHZyxhhFZumrQqkMqsbxatYSvZJFSWtTESoBqGSqb9F2pvQboik1uJyw7VNrDFUkvVj64JXY6cThHvWQpK96zqELurNjfEPjNRB79c5ESqqfK4FXtce",
            "5Jr8U6gPzoi9iYLRY4bVJBbYfsk95xM7AUyMhrsXzfG16nzkzcR2LpEsPFeYwS75WCDMGVta55SDWjb1cRPmWVKrKvr9A8RKRJkF3yop9gc2Kia4bccYqH1QcnNZAGoDLcqHiLSgbWwvjb1NaS2vVtUHsfnbKAQ64jX96gSMJis39UEh9HJiiA"
        ],
        signers: [
            TIPSigner(
                identity: "5HXAHFh8khYBGWA2V3oUUvXAX4aWnQsEyNzKoA3LnJkxtKQNhcWSh4Swt72a1bw7aG8uTg9F31ybzSJyuNHENUBtGobUfHbKNPUYYkHnhuPtWszaCuNJ3nBxZ4Crt8Q8AmJ2fZznLx3EDM2Eqf63drNmW6VVmmzBQUc4N2JaXzFtt4HFFWtvUk",
                index: 0,
                api: URL(string: "https://api.mixin.one/external/tip/mercury")!
            ),
            TIPSigner(
                identity: "5HrtnCWMLkh2R82iwztEorvRhdZkZwhE77ohPekJKumbko2gZ4RJ4HDiP9VRp1ZvjJi1CR7UB5WCxPGwcQS5oapXb2gtC7X37YhJ1TonFMfpiMy1a8w4VbrHsva3HyLeukUNvQ9vwn8eShRkqGXDhs83GGPcMjvpMWE7BrQuowCuzh5Rh1A3Zm",
                index: 1,
                api: URL(string: "https://api.mixin.one/external/tip/saturn")!
            ),
            TIPSigner(
                identity: "5JPtzVXJB5qPf4hZ8PgMFDyrqpjhUkYFSeLyME8mc61z7RErZxKj9To7CBhCpFPtt6LyfPH8D6knWjA8LgcAUjjS1EjbPzGNJ8GWFMP5ZtTh1HLgtLEnT5eJXvPHataxruYTmXMmuxZZiMKWvXf9crHggZBLPTaAxfgiis3JdwUUXYXhN91vi3",
                index: 2,
                api: URL(string: "https://api.mixin.one/external/tip/jupiter")!
            ),
            TIPSigner(
                identity: "5JZegBrWEedonzKwhWYhKjVuDd2ADWnFnnGWp7yjfAJCQSwwSFU7K22hwFeGtyHy9r8Zn7M5R6rX7WMYDQQupKP2NbqxsfSggxj3YrjC5msA4TdWavdLjFFPjNMdcCQHhUQhexkvxenDwjBgBFtsnHMMbSUTPk4nDQEjiF4J1ihZ6bwY3trTVD",
                index: 3,
                api: URL(string: "https://api.mixin.one/external/tip/mars")!
            ),
            TIPSigner(
                identity: "5JaU587MEXez1onCX7RkRyNkswfpdQ979Nsyv6niBFgUKJQmRTmoCy8phdUhMtwfzoJ8fu3zt8Mae1VVoTM5iNL4gP9zWkT8JscsNJSG5vnT6soM511V8exwmgUeXDfugNshJjqaskhyAAih4FfLxtV3NcBZk1zMDxnctwGQaM7z1G2L9Tf9H1",
                index: 4,
                api: URL(string: "https://api.mixin.one/external/tip/moon")!
            ),
            TIPSigner(
                identity: "5JaUby8CxXdEhYcEH2VEbkhdj6zDd1fj3wGdyTjiRQtres4yVoLhkHMf8wZ4qsNMhLvJgk9Mgae1Rs9cm6rY41yCTEzQQRA3a3D8FDDdv4dQms735noeqgxxzZs15utTnu7S5XFDiTUcMhue1Re7DZvvATKFpCbHzwoymU9yhXZBxsYCaHbULa",
                index: 5,
                api: URL(string: "https://api.mixin.one/external/tip/venus")!
            ),
            TIPSigner(
                identity: "5JrHfpJ6ML88u3nbvsB4dej7aHXdvShTEfxNF3mZ8no8wxsdhLTP4sh2Kt6AKboCcBRWGkFPky85e6DkMZsT3WSZ1q8V7gNF4Bdyipw7aS7TP8vtgG7USRJhVe36gNa8LJktf2a2chsWRT6egeB59wEyCHmgiNZpZSPwaezwS32ADTgCSDkzKY",
                index: 6,
                api: URL(string: "https://api.mixin.one/external/tip/sun")!
            )
        ]
    )
    
    public let commitments: [String]
    public let signers: [TIPSigner]
    
}
