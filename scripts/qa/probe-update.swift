// Probe the real signed feed without opening windows, installing, or touching Cove's preferences.
import AppKit
import Sparkle

final class Probe: NSObject, SPUUpdaterDelegate {
  var loaded = false
  var found = false
  var finished = false
  var failed = false
  let expected: Bool
  init(expected: Bool) { self.expected = expected }
  func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) { loaded = true }
  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    found = true
    print("Valid update: \(item.displayVersionString) (build \(item.versionString))")
  }
  func updaterDidNotFindUpdate(_ updater: SPUUpdater) { print("No newer update") }
  func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor check: SPUUpdateCheck, error: Error?) {
    finished = true
    if let error, !loaded { failed = true; print("Probe failed: \(error.localizedDescription)") }
  }
}
let args = CommandLine.arguments
precondition(args.count == 3, "Usage: probe-update HOST_APP expect-update|expect-current")
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let host = Bundle(path: args[1])!
let driver = SPUStandardUserDriver(hostBundle: host, delegate: nil)
let probe = Probe(expected: args[2] == "expect-update")
let updater = SPUUpdater(hostBundle: host, applicationBundle: host, userDriver: driver, delegate: probe)
try updater.start()
updater.checkForUpdateInformation()
let deadline = Date().addingTimeInterval(45)
while !probe.finished && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
guard probe.finished && probe.loaded && !probe.failed && probe.found == probe.expected else { exit(1) }
print("Signed feed probe passed; no windows or installation requested.")
