//
//  LicenseDefinition.swift
//  spm-audit
//
//  Created by Ricky Witherspoon on 1/31/26.
//

import Foundation

struct LicenseDefinition {
    let type: PackageUpdateResult.LicenseType
    let keywords: [String]
    let isPermissive: Bool

    static let all: [LicenseDefinition] = [
        // GNU licenses (check most specific first)
        LicenseDefinition(
            type: .agpl,
            keywords: ["GNU AFFERO GENERAL PUBLIC LICENSE", "AGPL"],
            isPermissive: false
        ),
        LicenseDefinition(
            type: .lgpl,
            keywords: ["GNU LESSER GENERAL PUBLIC LICENSE", "GNU LIBRARY GENERAL PUBLIC LICENSE", "LGPL"],
            isPermissive: false
        ),
        LicenseDefinition(
            type: .gpl,
            keywords: ["GNU GENERAL PUBLIC LICENSE", "GPL"],
            isPermissive: false
        ),

        // Permissive licenses
        LicenseDefinition(
            type: .mit,
            keywords: ["MIT LICENSE", "MIT", "PERMISSION IS HEREBY GRANTED"],
            isPermissive: true
        ),
        LicenseDefinition(
            type: .apache,
            keywords: ["APACHE LICENSE", "APACHE", "VERSION 2.0"],
            isPermissive: true
        ),
        LicenseDefinition(
            type: .bsd,
            keywords: ["BSD", "REDISTRIBUTION", "BSD-2-CLAUSE", "BSD-3-CLAUSE"],
            isPermissive: true
        ),
        LicenseDefinition(
            type: .isc,
            keywords: ["ISC LICENSE", "ISC", "PERMISSION TO USE"],
            isPermissive: true
        ),

        // Copyleft licenses
        LicenseDefinition(
            type: .mpl,
            keywords: ["MOZILLA PUBLIC LICENSE", "MPL"],
            isPermissive: false
        ),
        LicenseDefinition(
            type: .epl,
            keywords: ["ECLIPSE PUBLIC LICENSE", "EPL"],
            isPermissive: false
        ),
        LicenseDefinition(
            type: .eupl,
            keywords: ["EUROPEAN UNION PUBLIC LICENCE", "EUPL"],
            isPermissive: false
        ),

        // Public domain and permissive
        LicenseDefinition(
            type: .unlicense,
            keywords: ["UNLICENSE", "THIS IS FREE AND UNENCUMBERED SOFTWARE RELEASED INTO THE PUBLIC DOMAIN"],
            isPermissive: true
        ),
        LicenseDefinition(
            type: .cc0,
            keywords: ["CC0", "CREATIVE COMMONS ZERO"],
            isPermissive: true
        ),

        // Other licenses
        LicenseDefinition(
            type: .artistic,
            keywords: ["ARTISTIC LICENSE"],
            isPermissive: true
        ),
        LicenseDefinition(
            type: .boost,
            keywords: ["BOOST SOFTWARE LICENSE"],
            isPermissive: true
        ),
        LicenseDefinition(
            type: .wtfpl,
            keywords: ["WTFPL", "DO WHAT THE FUCK YOU WANT"],
            isPermissive: true
        ),
        LicenseDefinition(
            type: .zlib,
            keywords: ["ZLIB LICENSE"],
            isPermissive: true
        )
    ]

    func matches(_ content: String) -> Bool {
        let uppercased = content.uppercased()

        // Special case: exclude GPL matches that are actually LGPL or AGPL
        switch type {
        case .gpl:
            if uppercased.contains("LGPL") || uppercased.contains("AGPL") ||
               uppercased.contains("LESSER") || uppercased.contains("AFFERO") {
                return false
            }
            return keywords.contains { uppercased.contains($0) } && uppercased.contains("VERSION")
        default:
            // For other licenses, all keywords must be present
            return keywords.allSatisfy { uppercased.contains($0) }
        }
    }
}
