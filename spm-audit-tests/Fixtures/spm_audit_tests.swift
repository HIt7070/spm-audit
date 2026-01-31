//
//  spm_audit_tests.swift
//  spm-audit-tests
//
//  Created by Ricky Witherspoon on 1/31/26.
//

import Testing
import Foundation

@testable import spm_audit

struct RequirementTypeTests {

    @Test("Parse exactVersion requirement")
    func testExactVersionRequirement() async throws {
        let checker = PackageUpdateChecker()
        let fixturesURL = Bundle.module.resourceURL!.appendingPathComponent("exactVersion")

        let pbxprojPath = fixturesURL.appendingPathComponent("project.pbxproj").path
        let requirements = checker.extractRequirementTypesPublic(from: pbxprojPath)

        #expect(!requirements.isEmpty)

        // Should find swift-algorithms with exactVersion
        let algorithmRequirement = requirements.values.first
        #expect(algorithmRequirement == .exact)
    }

    @Test("Parse upToNextMajorVersion requirement")
    func testUpToNextMajorVersionRequirement() async throws {
        let checker = PackageUpdateChecker()
        let fixturesURL = Bundle.module.resourceURL!.appendingPathComponent("upToNextMajorVersion")

        let pbxprojPath = fixturesURL.appendingPathComponent("project.pbxproj").path
        let requirements = checker.extractRequirementTypesPublic(from: pbxprojPath)

        #expect(!requirements.isEmpty)

        let algorithmRequirement = requirements.values.first
        #expect(algorithmRequirement == .upToNextMajor)
    }

    @Test("Parse upToNextMinorVersion requirement")
    func testUpToNextMinorVersionRequirement() async throws {
        let checker = PackageUpdateChecker()
        let fixturesURL = Bundle.module.resourceURL!.appendingPathComponent("upToNextMinorVersion")

        let pbxprojPath = fixturesURL.appendingPathComponent("project.pbxproj").path
        let requirements = checker.extractRequirementTypesPublic(from: pbxprojPath)

        #expect(!requirements.isEmpty)

        let algorithmRequirement = requirements.values.first
        #expect(algorithmRequirement == .upToNextMinor)
    }

    @Test("Parse versionRange requirement")
    func testVersionRangeRequirement() async throws {
        let checker = PackageUpdateChecker()
        let fixturesURL = Bundle.module.resourceURL!.appendingPathComponent("versionRange")

        let pbxprojPath = fixturesURL.appendingPathComponent("project.pbxproj").path
        let requirements = checker.extractRequirementTypesPublic(from: pbxprojPath)

        #expect(!requirements.isEmpty)

        let algorithmRequirement = requirements.values.first
        #expect(algorithmRequirement == .range)
    }
}

struct PackageResolvedTests {

    @Test("Parse Package.resolved file")
    func testParsePackageResolved() async throws {
        let checker = PackageUpdateChecker()
        let fixturesURL = Bundle.module.resourceURL!.appendingPathComponent("exactVersion")

        let resolvedPath = fixturesURL.appendingPathComponent("Package.resolved").path
        let packages = checker.extractPackagesFromResolvedPublic(from: resolvedPath, includeTransitive: true)

        #expect(!packages.isEmpty)

        // Should find swift-algorithms
        let algorithmsPackage = packages.first { $0.name == "swift-algorithms" }
        #expect(algorithmsPackage != nil)
        #expect(algorithmsPackage?.requirementType == .exact)
    }

    @Test("Filter transitive dependencies by default")
    func testFilterTransitiveDependencies() async throws {
        let checker = PackageUpdateChecker()
        let fixturesURL = Bundle.module.resourceURL!.appendingPathComponent("exactVersion")

        let resolvedPath = fixturesURL.appendingPathComponent("Package.resolved").path

        // Without includeTransitive
        let directPackages = checker.extractPackagesFromResolvedPublic(from: resolvedPath, includeTransitive: false)

        // With includeTransitive
        let allPackages = checker.extractPackagesFromResolvedPublic(from: resolvedPath, includeTransitive: true)

        // Direct packages should be <= all packages
        #expect(directPackages.count <= allPackages.count)

        // All direct packages should have a requirement type
        for package in directPackages {
            #expect(package.requirementType != nil)
        }
    }
}

struct VersionComparisonTests {

    @Test("Compare semantic versions correctly")
    func testVersionComparison() async throws {
        let checker = PackageUpdateChecker()

        // 1.0.0 > 0.9.0
        #expect(checker.compareVersionsPublic("1.0.0", "0.9.0") == true)

        // 1.1.0 > 1.0.0
        #expect(checker.compareVersionsPublic("1.1.0", "1.0.0") == true)

        // 1.0.1 > 1.0.0
        #expect(checker.compareVersionsPublic("1.0.1", "1.0.0") == true)

        // 1.0.0 == 1.0.0
        #expect(checker.compareVersionsPublic("1.0.0", "1.0.0") == false)

        // 0.9.0 < 1.0.0
        #expect(checker.compareVersionsPublic("0.9.0", "1.0.0") == false)
    }

    @Test("Normalize version strings")
    func testVersionNormalization() async throws {
        let checker = PackageUpdateChecker()

        #expect(checker.normalizeVersionPublic("v1.0.0") == "1.0.0")
        #expect(checker.normalizeVersionPublic("1.0.0") == "1.0.0")
        #expect(checker.normalizeVersionPublic(" v1.0.0 ") == "1.0.0")
    }
}

struct SourceNameExtractionTests {

    @Test("Extract source name from Package.swift")
    func testExtractSourceNameFromPackageSwift() async throws {
        let checker = PackageUpdateChecker()

        let path = "/Users/test/MyProject/Package.swift"
        let sourceName = checker.extractSourceNamePublic(from: path)

        #expect(sourceName == "MyProject (Package.swift)")
    }

    @Test("Extract source name from nested Package.swift")
    func testExtractSourceNameFromNestedPackageSwift() async throws {
        let checker = PackageUpdateChecker()

        let path = "/Users/test/TestDrive/TestDriveKit/Package.swift"
        let sourceName = checker.extractSourceNamePublic(from: path)

        #expect(sourceName == "TestDriveKit (Package.swift)")
    }

    @Test("Extract source name from Xcode Package.resolved")
    func testExtractSourceNameFromXcodePackageResolved() async throws {
        let checker = PackageUpdateChecker()

        let path = "/Users/test/TestDrive/TestDrive.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        let sourceName = checker.extractSourceNamePublic(from: path)

        #expect(sourceName == "TestDrive (Xcode Project)")
    }

    @Test("Extract source name from standalone Package.resolved")
    func testExtractSourceNameFromStandalonePackageResolved() async throws {
        let checker = PackageUpdateChecker()

        let path = "/Users/test/SomePackage/Package.resolved"
        let sourceName = checker.extractSourceNamePublic(from: path)

        #expect(sourceName == "Package.resolved")
    }
}

struct PackageUpdaterTests {

    @Test("Reject Xcode project updates with clear error message")
    func testRejectXcodeProjectUpdates() async throws {
        let updater = PackageUpdater()
        let fixturesURL = Bundle.module.resourceURL!.appendingPathComponent("exactVersion")

        // Create a temporary copy
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let tempProjectDir = tempDir.appendingPathComponent("TestDrive.xcodeproj")
        try FileManager.default.createDirectory(at: tempProjectDir, withIntermediateDirectories: true)

        let workspaceDir = tempProjectDir.appendingPathComponent("project.xcworkspace/xcshareddata/swiftpm")
        try FileManager.default.createDirectory(at: workspaceDir, withIntermediateDirectories: true)
        let tempResolved = workspaceDir.appendingPathComponent("Package.resolved")
        let sourceResolved = fixturesURL.appendingPathComponent("Package.resolved")
        try FileManager.default.copyItem(at: sourceResolved, to: tempResolved)

        // Try to update an Xcode project package
        let package = PackageInfo(
            name: "swift-algorithms",
            url: "https://github.com/apple/swift-algorithms",
            currentVersion: "0.2.0",
            filePath: tempResolved.path,
            requirementType: .exact
        )

        do {
            try updater.updateFile(package: package, newVersion: "1.0.0")
            #expect(Bool(false), "Should have thrown xcodeProjectNotSupported error")
        } catch let error as UpdateError {
            if case .xcodeProjectNotSupported(let name) = error {
                #expect(name == "swift-algorithms")
                #expect(error.description.contains("Xcode project updates are not currently supported"))
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Update Package.swift successfully")
    func testUpdatePackageSwift() async throws {
        let updater = PackageUpdater()

        // Create a temporary Package.swift file
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let packageSwiftPath = tempDir.appendingPathComponent("Package.swift")
        let packageContent = """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "TestPackage",
            dependencies: [
                .package(url: "https://github.com/apple/swift-algorithms", exact: "1.0.0")
            ]
        )
        """
        try packageContent.write(to: URL(fileURLWithPath: packageSwiftPath.path), atomically: true, encoding: .utf8)

        let package = PackageInfo(
            name: "swift-algorithms",
            url: "https://github.com/apple/swift-algorithms",
            currentVersion: "1.0.0",
            filePath: packageSwiftPath.path,
            requirementType: .exact
        )

        try updater.updateFile(package: package, newVersion: "1.2.0")

        // Verify the update
        let updatedContent = try String(contentsOfFile: packageSwiftPath.path, encoding: .utf8)
        #expect(updatedContent.contains("exact: \"1.2.0\""))
        #expect(!updatedContent.contains("exact: \"1.0.0\""))

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Validate version format")
    func testValidateVersionFormat() async throws {
        let updater = PackageUpdater()

        #expect(updater.isValidVersionPublic("1.0.0") == true)
        #expect(updater.isValidVersionPublic("1.0") == true)
        #expect(updater.isValidVersionPublic("2.1.3") == true)
        #expect(updater.isValidVersionPublic("invalid") == false)
        #expect(updater.isValidVersionPublic("1") == false)
        #expect(updater.isValidVersionPublic("1.2.3.4") == false)
    }

    @Test("Update multiple packages in Package.swift")
    func testUpdateMultiplePackages() async throws {
        let updater = PackageUpdater()

        // Create a temporary Package.swift with multiple packages
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let packageSwiftPath = tempDir.appendingPathComponent("Package.swift")
        let packageContent = """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "TestPackage",
            dependencies: [
                .package(url: "https://github.com/apple/swift-algorithms", exact: "1.0.0"),
                .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.5.0")
            ]
        )
        """
        try packageContent.write(to: URL(fileURLWithPath: packageSwiftPath.path), atomically: true, encoding: .utf8)

        let package = PackageInfo(
            name: "swift-algorithms",
            url: "https://github.com/apple/swift-algorithms",
            currentVersion: "1.0.0",
            filePath: packageSwiftPath.path,
            requirementType: .exact
        )

        try updater.updateFile(package: package, newVersion: "1.2.0")

        // Verify only the specific package was updated
        let updatedContent = try String(contentsOfFile: packageSwiftPath.path, encoding: .utf8)
        #expect(updatedContent.contains("exact: \"1.2.0\""))
        #expect(!updatedContent.contains("exact: \"1.0.0\""))
        // Other package should remain unchanged
        #expect(updatedContent.contains("exact: \"1.5.0\""))

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
}

struct VersionTests {

    @Test("Version constant is valid semantic version")
    func testVersionFormat() async throws {
        // Version should be in semantic version format (X.Y.Z)
        let components = currentVersion.split(separator: ".")

        #expect(components.count == 3, "Version should have 3 components (major.minor.patch)")

        // Each component should be a valid integer
        for component in components {
            #expect(Int(component) != nil, "Version component '\(component)' should be a number")
        }
    }

    @Test("Version constant matches expected format")
    func testVersionNotEmpty() async throws {
        #expect(!currentVersion.isEmpty, "Version should not be empty")
        #expect(!currentVersion.contains("v"), "Version should not contain 'v' prefix")
        #expect(!currentVersion.contains(" "), "Version should not contain spaces")
    }
}

// Expose internal methods for testing
extension PackageUpdater {
    func isValidVersionPublic(_ version: String) -> Bool {
        return isValidVersion(version)
    }
}
