//
//  ProcessExecutor.swift
//  PhotoCropper
//
//  Utility for safely executing external command-line processes
//

import Foundation

// MARK: - Process Executor

/// Utility class for executing external command-line processes
///
/// This class encapsulates the complexity of `posix_spawn` and provides
/// a safe, memory-managed API for executing external commands.
///
/// ## Memory Safety
/// All C string memory (argv/envp arrays) is automatically managed.
/// You don't need to worry about strdup/free operations.
///
/// ## Usage Example
/// ```swift
/// let result = ProcessExecutor.execute(
///     command: "/usr/bin/ls",
///     arguments: ["-la", "/tmp"],
///     environment: ["PATH=/usr/bin"]
/// )
///
/// switch result {
/// case .success(let output):
///     print("Command output: \(output)")
/// case .failure(let error):
///     print("Error: \(error)")
/// }
/// ```
class ProcessExecutor {
    
    // MARK: - Execution
    
    /// Executes an external command and waits for completion
    ///
    /// This method uses `posix_spawn` to execute a command with proper
    /// memory management and error handling.
    ///
    /// - Parameters:
    ///   - command: Full path to the executable
    ///   - arguments: Array of command-line arguments (not including the command itself)
    ///   - environment: Optional environment variables (e.g., ["PATH=/usr/bin"])
    ///   - captureOutput: Whether to capture stdout/stderr (default: false)
    ///
    /// - Returns: Result with exit code or error
    ///
    /// - Note: The command path is automatically added as argv[0].
    ///   Do not include it in the arguments array.
    ///
    /// Example:
    /// ```swift
    /// // Execute: /usr/bin/grep "error" file.txt
    /// let result = ProcessExecutor.execute(
    ///     command: "/usr/bin/grep",
    ///     arguments: ["error", "file.txt"]
    /// )
    /// ```
    static func execute(
        command: String,
        arguments: [String] = [],
        environment: [String]? = nil,
        captureOutput: Bool = false
    ) -> Result<Int32, ProcessExecutorError> {
        
        // Build argv array (command + arguments + NULL)
        var argvStrings = [command] + arguments
        let argv = buildCStringArray(from: argvStrings)
        
        // Build envp array if provided
        let envp: [UnsafeMutablePointer<CChar>?]
        if let env = environment {
            envp = buildCStringArray(from: env)
        } else {
            envp = [nil]  // NULL-terminated empty array
        }
        
        // Spawn the process
        var pid: pid_t = 0
        let spawnStatus = posix_spawn(&pid, command, nil, nil, argv, envp)
        
        // Cleanup memory
        cleanupCStringArray(argv)
        if environment != nil {
            cleanupCStringArray(envp)
        }
        
        // Check if spawn was successful
        guard spawnStatus == 0 else {
            let errorMessage = String(cString: strerror(spawnStatus))
            return .failure(.spawnFailed(status: spawnStatus, message: errorMessage))
        }
        
        // Wait for process to complete
        var exitStatus: Int32 = 0
        var waitResult: pid_t
        var waitErrno: Int32 = 0
        // Retry if a caught signal interrupts the wait (EINTR); the child keeps running
        repeat {
            waitResult = waitpid(pid, &exitStatus, 0)
            waitErrno = errno  // capture before any other call can overwrite it
        } while waitResult == -1 && waitErrno == EINTR

        guard waitResult > 0 else {
            return .failure(.waitFailed(pid: pid, errorCode: waitErrno))
        }
        
        // Extract actual exit code
        let actualExitCode = (exitStatus >> 8) & 0xFF
        
        return .success(actualExitCode)
    }
    
    /// Executes a command and ensures it succeeds (exit code 0)
    ///
    /// This is a convenience method that returns success only if the
    /// command exits with code 0.
    ///
    /// - Parameters:
    ///   - command: Full path to the executable
    ///   - arguments: Array of command-line arguments
    ///   - environment: Optional environment variables
    ///
    /// - Returns: Result indicating success or failure with detailed error
    ///
    /// Example:
    /// ```swift
    /// let result = ProcessExecutor.executeAndVerify(
    ///     command: "/usr/bin/touch",
    ///     arguments: ["/tmp/test.txt"]
    /// )
    /// ```
    static func executeAndVerify(
        command: String,
        arguments: [String] = [],
        environment: [String]? = nil
    ) -> Result<Void, ProcessExecutorError> {
        
        let result = execute(
            command: command,
            arguments: arguments,
            environment: environment
        )
        
        switch result {
        case .success(let exitCode):
            if exitCode == 0 {
                return .success(())
            } else {
                return .failure(.nonZeroExit(
                    command: command,
                    exitCode: exitCode
                ))
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Memory Management
    
    /// Builds a NULL-terminated C string array from Swift strings
    ///
    /// - Parameter strings: Array of Swift strings
    /// - Returns: C string array with NULL terminator
    ///
    /// - Note: Caller is responsible for calling `cleanupCStringArray` to free memory
    private static func buildCStringArray(from strings: [String]) -> [UnsafeMutablePointer<CChar>?] {
        var array = strings.map { strdup($0) }
        array.append(nil)  // NULL terminator
        return array
    }
    
    /// Frees memory allocated for a C string array
    ///
    /// - Parameter array: C string array to cleanup
    private static func cleanupCStringArray(_ array: [UnsafeMutablePointer<CChar>?]) {
        array.forEach { ptr in
            if let ptr = ptr {
                free(ptr)
            }
        }
    }
}

// MARK: - Process Executor Errors

/// Errors that can occur during process execution
enum ProcessExecutorError: LocalizedError {
    /// posix_spawn failed to start the process
    case spawnFailed(status: Int32, message: String)
    
    /// waitpid failed to wait for process completion (`errorCode` is the errno value)
    case waitFailed(pid: pid_t, errorCode: Int32)
    
    /// Command exited with non-zero exit code
    case nonZeroExit(command: String, exitCode: Int32)
    
    /// Command could not be found at the specified path
    case commandNotFound(path: String)
    
    var errorDescription: String? {
        switch self {
        case .spawnFailed(let status, let message):
            return "Failed to spawn process (status \(status)): \(message)"
        case .waitFailed(let pid, let errorCode):
            return "Failed to wait for process completion (pid: \(pid)): \(String(cString: strerror(errorCode))) (errno \(errorCode))"
        case .nonZeroExit(let command, let exitCode):
            let commandName = (command as NSString).lastPathComponent
            return "\(commandName) exited with code \(exitCode)"
        case .commandNotFound(let path):
            return "Command not found: \(path)"
        }
    }
}

