// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "SalaryClockMacOS", platforms: [.macOS(.v14)], targets: [
    .executableTarget(name: "Clock"),
    .testTarget(name: "ClockTests", dependencies: ["Clock"])
])
