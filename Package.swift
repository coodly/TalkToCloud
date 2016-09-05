import PackageDescription

let package = Package(
    name: "TalkToCloud",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/CommonCrypto.git", Version(0, 1, 4)),
    ]
)
