//
//  Process+WaitWithoutRunLoop.swift
//  PhotoCropper
//
//  Runs a process and waits for it without spinning the run loop
//

import Foundation

extension Process {
    /// Runs the process, reads `outputPipe` to the end and blocks until the process has exited.
    ///
    /// Unlike `waitUntilExit()`, this does not spin the run loop. A spinning run loop lets other
    /// main-actor work (SwiftUI updates, the next image's `.task`) run nested inside the caller.
    ///
    /// - Parameter outputPipe: The pipe assigned to `standardOutput`
    /// - Returns: Everything the process wrote to `outputPipe`
    /// - Throws: The error of `run()` if the process cannot be started
    func runAndWaitWithoutRunLoop(readingOutputFrom outputPipe: Pipe) throws -> Data {
        let terminated = DispatchSemaphore(value: 0)
        // Must be set before run(); it is called on a background queue
        terminationHandler = { _ in terminated.signal() }
        try run()
        // Read before waiting, so a full pipe buffer cannot block the process
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        terminated.wait()
        return data
    }
}
