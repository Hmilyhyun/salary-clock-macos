// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "SalaryClockMacOS", platforms: [.macOS(.v14)], targets: [
    .executableTarget(name: "Clock", resources: [.copy("Resources/salary.js")])
])
