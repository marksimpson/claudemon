import Foundation

public enum ITerm {
    public static func parseGUID(from itermSessionId: String) -> String? {
        guard let colonIndex = itermSessionId.firstIndex(of: ":") else { return nil }
        let afterColon = itermSessionId.index(after: colonIndex)
        guard afterColon < itermSessionId.endIndex else { return nil }
        return String(itermSessionId[afterColon...])
    }

    public static func activationScript(for guid: String) -> String {
        """
        tell application "iTerm2"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if unique ID of s is "\(guid)" then
                            select t
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
    }

    public static func activateSession(itermSessionId: String) {
        guard let guid = parseGUID(from: itermSessionId) else { return }
        let source = activationScript(for: guid)
        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }
}
