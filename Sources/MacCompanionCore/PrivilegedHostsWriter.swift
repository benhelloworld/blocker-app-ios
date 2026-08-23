import Foundation
import Darwin

public struct PrivilegedHostsWriter {
    private let hostsURL = URL(fileURLWithPath: "/etc/hosts")

    public init() {}

    public func currentHosts() throws -> String {
        try String(contentsOf: hostsURL, encoding: .utf8)
    }

    public func apply(domains: [String]) throws {
        let manager = HostsFileManager()
        let cleanDomains = try manager.sanitizedDomains(domains)
        let nextHosts = try manager.updatedHosts(existingHosts: currentHosts(), domains: cleanDomains)
        let blockedIPs = Self.resolveIPs(for: cleanDomains)
        try writeProtectionWithAdminAuthorization(hosts: nextHosts, blockedIPs: blockedIPs)
    }

    public func clearManagedBlock() throws {
        let manager = HostsFileManager()
        let nextHosts = manager.clearedHosts(existingHosts: try currentHosts())
        try writeProtectionWithAdminAuthorization(hosts: nextHosts, blockedIPs: [])
    }

    public static func resolveIPs(for domains: [String]) -> [String] {
        var results = Set<String>()

        for domain in domains {
            var hints = addrinfo(
                ai_flags: 0,
                ai_family: AF_UNSPEC,
                ai_socktype: SOCK_STREAM,
                ai_protocol: IPPROTO_TCP,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil
            )
            var pointer: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(domain, "443", &hints, &pointer) == 0, let pointer else { continue }
            defer { freeaddrinfo(pointer) }

            var cursor: UnsafeMutablePointer<addrinfo>? = pointer
            while let info = cursor {
                if let address = info.pointee.ai_addr {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let status = getnameinfo(
                        address,
                        info.pointee.ai_addrlen,
                        &host,
                        socklen_t(host.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    if status == 0 {
                        let ip = String(cString: host)
                        if ip != "0.0.0.0" && ip != "::1" && ip != "127.0.0.1" {
                            results.insert(ip)
                        }
                    }
                }
                cursor = info.pointee.ai_next
            }
        }

        return results.sorted()
    }

    private func writeProtectionWithAdminAuthorization(hosts: String, blockedIPs: [String]) throws {
        let helperBase64 = Data(Self.helperScript.utf8).base64EncodedString()
        let hostsBase64 = Data(hosts.utf8).base64EncodedString()
        let pfBase64 = Data(Self.pfRules(for: blockedIPs).utf8).base64EncodedString()
        let privilegedShell = """
        set -e
        umask 077
        temp_dir=$(/usr/bin/mktemp -d /private/tmp/blockerapp.XXXXXX)
        trap '/bin/rm -rf "$temp_dir"' EXIT HUP INT TERM
        helper_file="$temp_dir/helper"
        hosts_file="$temp_dir/hosts"
        pf_file="$temp_dir/pf"

        /bin/echo '__HELPER_BASE64__' | /usr/bin/base64 --decode > "$helper_file"
        /usr/sbin/chown root:wheel "$helper_file"
        /bin/chmod 0700 "$helper_file"
        /bin/rm -f /etc/sudoers.d/blockerapp-mac-companion /usr/local/bin/blockerapp-helper

        /bin/echo '__HOSTS_BASE64__' | /usr/bin/base64 --decode > "$hosts_file"
        /bin/echo '__PF_BASE64__' | /usr/bin/base64 --decode > "$pf_file"
        "$helper_file" apply "$hosts_file" "$pf_file"
        """
            .replacingOccurrences(of: "__HELPER_BASE64__", with: helperBase64)
            .replacingOccurrences(of: "__HOSTS_BASE64__", with: hostsBase64)
            .replacingOccurrences(of: "__PF_BASE64__", with: pfBase64)

        let escapedShell = Self.escapeForAppleScript(privilegedShell)
        let appleScript = "do shell script \"\(escapedShell)\" with administrator privileges"
        let result = try runProcess(executable: "/usr/bin/osascript", arguments: ["-e", appleScript])
        guard result.status == 0 else {
            throw HostsFileManagerError.scriptFailed(Self.cleanProcessMessage(result.message, fallback: "Admin authorization was cancelled or failed."))
        }
    }

    private func runProcess(executable: String, arguments: [String]) throws -> (status: Int32, message: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, [output, error].filter { !$0.isEmpty }.joined(separator: "\n"))
    }

    private static func escapeForAppleScript(_ shell: String) -> String {
        shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func cleanProcessMessage(_ message: String, fallback: String) -> String {
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }

    public static func pfRules(for blockedIPs: [String]) -> String {
        guard !blockedIPs.isEmpty else { return "" }
        let list = blockedIPs.joined(separator: ", ")
        return """
        table <blockerapp_blocked> persist { \(list) }
        block drop out quick to <blockerapp_blocked>
        """
    }

    public static let helperScript = """
    #!/bin/sh
    set -eu

    command="${1:-}"
    hosts_file="${2:-}"
    pf_file="${3:-}"
    anchor_path="/etc/pf.anchors/com.blockerapp.maccompanion"

    if [ "$command" != "apply" ]; then
        echo "Unsupported Blocker helper command: $command" >&2
        exit 64
    fi

    case "$hosts_file" in
        /private/tmp/blockerapp.*/hosts) ;;
        *) echo "Unexpected hosts temp path: $hosts_file" >&2; exit 65 ;;
    esac
    case "$pf_file" in
        /private/tmp/blockerapp.*/pf) ;;
        *) echo "Unexpected firewall temp path: $pf_file" >&2; exit 65 ;;
    esac

    if [ ! -f "$hosts_file" ] || [ -L "$hosts_file" ] || [ ! -f "$pf_file" ] || [ -L "$pf_file" ]; then
        echo "Blocker helper could not find the prepared rule files." >&2
        exit 66
    fi
    if [ "$(/usr/bin/stat -f %u "$hosts_file")" != "0" ] || [ "$(/usr/bin/stat -f %u "$pf_file")" != "0" ]; then
        echo "Blocker helper requires root-owned rule files." >&2
        exit 67
    fi

    if [ ! -f /etc/hosts.blockerapp.backup ]; then
        /bin/cp /etc/hosts /etc/hosts.blockerapp.backup
    fi
    /bin/cp "$hosts_file" /etc/hosts

    /bin/mkdir -p /etc/pf.anchors
    /bin/cp "$pf_file" "$anchor_path"

    /sbin/pfctl -a com.blockerapp.maccompanion -F all >/dev/null 2>&1 || true
    if [ -s "$anchor_path" ]; then
        /sbin/pfctl -a com.blockerapp.maccompanion -f "$anchor_path"
        /sbin/pfctl -E >/dev/null 2>&1 || true
    fi

    /usr/bin/dscacheutil -flushcache
    /usr/bin/killall -HUP mDNSResponder 2>/dev/null || true
    """
}
