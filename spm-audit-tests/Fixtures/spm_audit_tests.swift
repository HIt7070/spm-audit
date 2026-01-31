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
