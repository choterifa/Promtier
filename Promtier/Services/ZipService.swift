//
//  ZipService.swift
//  Promtier
//
//  Utilidad para crear/extraer ZIP usando /usr/bin/ditto (macOS).
//

import Foundation

enum ZipService {
    enum ZipError: Error {
        case toolFailed(exitCode: Int32, output: String)
    }

    static func zip(directory sourceDirectory: URL, to destinationZip: URL) throws {
        try runDitto(arguments: [
            "-c", "-k",
            "--sequesterRsrc",
            "--keepParent",
            sourceDirectory.path,
            destinationZip.path
        ])
    }

    static func unzip(zipFile: URL, to destinationDirectory: URL) throws {
        try runDitto(arguments: [
            "-x", "-k",
            zipFile.path,
            destinationDirectory.path
        ])
    }

    private static func runDitto(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw ZipError.toolFailed(exitCode: process.terminationStatus, output: output)
        }
    }
}

