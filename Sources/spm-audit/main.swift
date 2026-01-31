//
//  main.swift
//  spm-audit
//
//  Created by Ricky Witherspoon on 1/31/26.
//

import Foundation
import ArgumentParser

// MARK: - Models

struct PackageInfo: Codable {
    let name: String
    let url: String
    let currentVersion: String
    let filePath: String
    let requirementType: RequirementType?

    enum RequirementType: String, Codable {
        case exact = "exact"
        case upToNextMajor = "upToNextMajorVersion"
        case upToNextMinor = "upToNextMinorVersion"
        case range = "versionRange"
        case branch = "branch"
        case revision = "revision"

        var displayName: String {
            switch self {
            case .exact: return "Exact"
            case .upToNextMajor: return "^Major"
            case .upToNextMinor: return "^Minor"
            case .range: return "Range"
            case .branch: return "Branch"
            case .revision: return "Revision"
            }
        }
    }
}

struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case prerelease
    }
}

struct PackageUpdateResult {
    let package: PackageInfo
    let status: UpdateStatus

    enum UpdateStatus {
        case upToDate(String)
        case updateAvailable(current: String, latest: String)
        case noReleases
        case error(String)
    }
}

struct PackageResolved: Codable {
    let pins: [Pin]
    let version: Int

    struct Pin: Codable {
        let identity: String
        let location: String
        let state: State

        struct State: Codable {
            let version: String?
        }
    }
}

// MARK: - Main

final class PackageUpdateChecker {
    private let fileManager = FileManager.default
    private let workingDirectory: String
    private let githubToken: String?
    private let includeTransitive: Bool

    init(workingDirectory: String? = nil, includeTransitive: Bool = false) {
        self.workingDirectory = workingDirectory ?? fileManager.currentDirectoryPath
        self.githubToken = Self.getGitHubToken()
        self.includeTransitive = includeTransitive
    }

    private static func getGitHubToken() -> String? {
        // First check environment variable
        if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
            return token
        }

        // Fall back to gh CLI token
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "auth", "token"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !token.isEmpty {
                    return token
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    func run() async {
        print("🔍 Scanning for Package.swift and Xcode project files...\n")

        let packages = findPackages()

        if packages.isEmpty {
            print("❌ No packages with exact versions found.")
            return
        }

        print("📦 Found \(packages.count) package(s) with exact versions")
        print("⚡️ Checking for updates in parallel...\n")

        // Check all packages in parallel and collect results
        var results: [PackageUpdateResult] = []
        await withTaskGroup(of: PackageUpdateResult.self) { group in
            for package in packages {
                group.addTask {
                    await self.checkForUpdatesAsync(package: package)
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        // Sort results by package name for consistent display
        results.sort { $0.package.name < $1.package.name }

        // Print results in table format
        printTable(results)
    }

    // MARK: - Private Helpers

    private func findPackages() -> [PackageInfo] {
        var packages: [PackageInfo] = []

        guard let enumerator = fileManager.enumerator(atPath: workingDirectory) else {
            return packages
        }

        for case let path as String in enumerator {
            // Skip .build directories
            if path.contains("/.build/") {
                continue
            }

            if path.hasSuffix("Package.swift") {
                let fullPath = (workingDirectory as NSString).appendingPathComponent(path)
                packages.append(contentsOf: extractPackagesFromSwiftPackage(from: fullPath))
            } else if path.hasSuffix("Package.resolved") {
                let fullPath = (workingDirectory as NSString).appendingPathComponent(path)
                packages.append(contentsOf: extractPackagesFromResolved(from: fullPath, includeTransitive: includeTransitive))
            }
        }

        // Remove duplicates based on URL
        var seen: Set<String> = []
        return packages.filter { package in
            if seen.contains(package.url) {
                return false
            }
            seen.insert(package.url)
            return true
        }
    }

    private func extractPackagesFromSwiftPackage(from filePath: String) -> [PackageInfo] {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return []
        }

        var packages: [PackageInfo] = []

        // Pattern to match: url: "https://github.com/...", exact: "1.0.0"
        let pattern = #"url:\s*"(https://github\.com/[^"]+)",\s*exact:\s*"([^"]+)""#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsContent = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))

        for match in matches {
            if match.numberOfRanges == 3 {
                let urlRange = match.range(at: 1)
                let versionRange = match.range(at: 2)

                let url = nsContent.substring(with: urlRange)
                let version = nsContent.substring(with: versionRange)

                // Extract package name from URL
                let name = url.components(separatedBy: "/").last ?? "Unknown"

                packages.append(PackageInfo(
                    name: name,
                    url: url,
                    currentVersion: version,
                    filePath: filePath,
                    requirementType: .exact
                ))
            }
        }

        return packages
    }

    private func extractPackagesFromResolved(from filePath: String, includeTransitive: Bool) -> [PackageInfo] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              let resolved = try? JSONDecoder().decode(PackageResolved.self, from: data) else {
            return []
        }

        // Find the project.pbxproj file to extract requirement types
        let projectPath = (filePath as NSString).deletingLastPathComponent
            .replacingOccurrences(of: "/project.xcworkspace/xcshareddata/swiftpm", with: "")
        let pbxprojPath = "\(projectPath)/project.pbxproj"
        let requirementTypes = extractRequirementTypes(from: pbxprojPath)

        var packages: [PackageInfo] = []

        for pin in resolved.pins {
            // Only include packages with versions (not branch/revision only)
            guard let version = pin.state.version else {
                continue
            }

            // Only include GitHub packages
            guard pin.location.contains("github.com") else {
                continue
            }

            // Clean up URL by removing .git suffix
            let cleanURL = pin.location.replacingOccurrences(of: ".git", with: "")

            // Get requirement type for this package
            let requirementType = requirementTypes[cleanURL] ?? requirementTypes[pin.location]

            // Skip transitive dependencies (packages not directly referenced in project.pbxproj)
            // unless includeTransitive flag is set
            if !includeTransitive && requirementType == nil {
                continue
            }

            // Extract package name from location
            let name = cleanURL.components(separatedBy: "/").last ?? pin.identity

            packages.append(PackageInfo(
                name: name,
                url: cleanURL,
                currentVersion: version,
                filePath: filePath,
                requirementType: requirementType
            ))
        }

        return packages
    }

    private func extractRequirementTypes(from pbxprojPath: String) -> [String: PackageInfo.RequirementType] {
        guard let content = try? String(contentsOfFile: pbxprojPath, encoding: .utf8) else {
            return [:]
        }

        var requirements: [String: PackageInfo.RequirementType] = [:]

        // Pattern to match XCRemoteSwiftPackageReference sections
        let pattern = #"XCRemoteSwiftPackageReference[^}]+repositoryURL = "([^"]+)";[^}]+requirement = \{[^}]*kind = (\w+);"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return [:]
        }

        let nsContent = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))

        for match in matches {
            if match.numberOfRanges == 3 {
                let urlRange = match.range(at: 1)
                let kindRange = match.range(at: 2)

                let url = nsContent.substring(with: urlRange).replacingOccurrences(of: ".git", with: "")
                let kind = nsContent.substring(with: kindRange)

                if let requirementType = PackageInfo.RequirementType(rawValue: kind) {
                    requirements[url] = requirementType
                }
            }
        }

        return requirements
    }

    private func checkForUpdatesAsync(package: PackageInfo) async -> PackageUpdateResult {
        // Extract owner and repo from GitHub URL
        let components = package.url.components(separatedBy: "/")
        guard components.count >= 5,
              let ownerIndex = components.firstIndex(of: "github.com"),
              ownerIndex + 2 < components.count else {
            return PackageUpdateResult(
                package: package,
                status: .error("Could not parse GitHub URL")
            )
        }

        let owner = components[ownerIndex + 1]
        let repo = components[ownerIndex + 2]

        return await fetchLatestRelease(owner: owner, repo: repo, package: package)
    }

    private func printTable(_ results: [PackageUpdateResult]) {
        // Calculate column widths
        let nameWidth = max(
            results.map { $0.package.name.count }.max() ?? 0,
            "Package".count
        ) + 2

        let typeWidth = 10 // "Exact", "Range", etc.

        let currentWidth = max(
            results.map { $0.package.currentVersion.count }.max() ?? 0,
            "Current".count
        ) + 2

        let latestWidth = max(
            results.compactMap { result -> Int? in
                switch result.status {
                case .upToDate(let v), .updateAvailable(_, let v):
                    return v.count
                default:
                    return nil
                }
            }.max() ?? 0,
            "Latest".count
        ) + 2

        let statusWidth = 20

        // Print header
        let separator = "+" + String(repeating: "-", count: nameWidth) +
                       "+" + String(repeating: "-", count: typeWidth) +
                       "+" + String(repeating: "-", count: currentWidth) +
                       "+" + String(repeating: "-", count: latestWidth) +
                       "+" + String(repeating: "-", count: statusWidth) + "+"

        print(separator)
        print("| \(pad("Package", width: nameWidth - 2))" +
              " | \(pad("Type", width: typeWidth - 2))" +
              " | \(pad("Current", width: currentWidth - 2))" +
              " | \(pad("Latest", width: latestWidth - 2))" +
              " | \(pad("Status", width: statusWidth - 2)) |")
        print(separator)

        // Print rows
        for result in results {
            let name = result.package.name
            let type = result.package.requirementType?.displayName ?? "Unknown"
            let current = result.package.currentVersion

            let (latest, status) = getLatestAndStatus(result.status)

            print("| \(pad(name, width: nameWidth - 2))" +
                  " | \(pad(type, width: typeWidth - 2))" +
                  " | \(pad(current, width: currentWidth - 2))" +
                  " | \(pad(latest, width: latestWidth - 2))" +
                  " | \(pad(status, width: statusWidth - 2)) |")
        }

        print(separator)

        // Print summary
        let updateCount = results.filter {
            if case .updateAvailable = $0.status { return true }
            return false
        }.count

        print("\n📊 Summary: \(updateCount) update(s) available")
    }

    private func pad(_ text: String, width: Int) -> String {
        let padding = width - text.count
        if padding <= 0 {
            return text
        }
        return text + String(repeating: " ", count: padding)
    }

    private func getLatestAndStatus(_ status: PackageUpdateResult.UpdateStatus) -> (String, String) {
        switch status {
        case .upToDate(let latest):
            return (latest, "✅ Up to date")
        case .updateAvailable(_, let latest):
            return (latest, "⚠️  Update available")
        case .noReleases:
            return ("N/A", "⚠️  No releases")
        case .error:
            return ("N/A", "❌ Error")
        }
    }

    private func fetchLatestRelease(owner: String, repo: String, package: PackageInfo) async -> PackageUpdateResult {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases"

        guard let url = URL(string: urlString) else {
            return PackageUpdateResult(package: package, status: .error("Invalid API URL"))
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        // Add GitHub token if available (for private repos)
        if let token = githubToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return PackageUpdateResult(package: package, status: .error("Invalid response"))
            }

            if httpResponse.statusCode == 404 {
                return PackageUpdateResult(package: package, status: .noReleases)
            }

            guard httpResponse.statusCode == 200 else {
                return PackageUpdateResult(
                    package: package,
                    status: .error("API error (status \(httpResponse.statusCode))")
                )
            }

            let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)

            // Filter out prereleases and find the latest
            let stableReleases = releases.filter { !$0.prerelease }

            guard let latestRelease = stableReleases.first else {
                return PackageUpdateResult(package: package, status: .noReleases)
            }

            let latestVersion = normalizeVersion(latestRelease.tagName)

            if compareVersions(latestVersion, package.currentVersion) {
                return PackageUpdateResult(
                    package: package,
                    status: .updateAvailable(current: package.currentVersion, latest: latestVersion)
                )
            } else {
                return PackageUpdateResult(
                    package: package,
                    status: .upToDate(latestVersion)
                )
            }

        } catch {
            return PackageUpdateResult(
                package: package,
                status: .error(error.localizedDescription)
            )
        }
    }

    private func normalizeVersion(_ version: String) -> String {
        // Remove 'v' prefix and normalize
        version.replacingOccurrences(of: "v", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func compareVersions(_ latest: String, _ current: String) -> Bool {
        // Split versions into components
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }

        // Pad to same length (e.g., 2.3 becomes [2, 3, 0])
        let maxLength = max(latestComponents.count, currentComponents.count)
        var latestPadded = latestComponents
        var currentPadded = currentComponents

        while latestPadded.count < maxLength {
            latestPadded.append(0)
        }
        while currentPadded.count < maxLength {
            currentPadded.append(0)
        }

        // Compare component by component
        for (l, c) in zip(latestPadded, currentPadded) {
            if l > c {
                return true  // Update available
            } else if l < c {
                return false // Current is newer
            }
        }

        return false // Equal
    }
}

// MARK: - Entry Point

@main
struct SPMAudit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "spm-audit",
        abstract: "Check for Swift Package Manager dependency updates",
        discussion: """
            Scans for Package.swift files with exact version dependencies and checks
            GitHub for the latest available releases. Supports authentication via
            GITHUB_TOKEN environment variable or gh CLI.
            """,
        version: "1.0.0"
    )

    @Argument(
        help: "The directory to scan for Package.swift files (defaults to current directory)",
        completion: .directory
    )
    var directory: String?

    @Flag(name: .shortAndLong, help: "Include transitive dependencies (dependencies of dependencies)")
    var all: Bool = false

    func run() async throws {
        let checker = PackageUpdateChecker(workingDirectory: directory, includeTransitive: all)
        await checker.run()
    }
}
