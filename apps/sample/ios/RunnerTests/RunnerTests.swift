import Flutter
import StoreKit
import StoreKitTest
import UIKit
import XCTest
import integration_test

/// Runs `integration_test/` of the sample under StoreKit testing.
///
/// `flutter run` does not take the scheme's StoreKit file; this test host does:
/// the session below is made from `Runner/Products.storekit` and lives in the
/// app's own process (the tests are hosted by Runner), so what the Dart side
/// buys goes to the local StoreKit and no system sheet is shown. The Dart test
/// reaches the session through the `storekit_test` channel: it reads the
/// store's transactions (what the real App Store would answer the server) and
/// moves the store's time (cancel, expire, refund).
class RunnerTests: XCTestCase {
  private var session: SKTestSession?

  private let storeFile = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Runner/Products.storekit")

  /// A fresh test store numbers its first transaction 0, and the `in_app_purchase`
  /// plugin reads id 0 as "no id" (`purchaseID` null; the real store never gives 0).
  /// One purchase that is made and finished here moves the numbering on (clearing
  /// the transactions would start at 0 again).
  private func resetStore(_ session: SKTestSession, done: @escaping () -> Void) throws {
    session.resetToDefaultState()
    session.clearTransactions()
    // reset gives the settings their defaults back: dialogs off comes after it
    session.disableDialogs = true
    try session.buyProduct(productIdentifier: "com.example.sample.cheer3000")
    Task {
      for await verified in Transaction.unfinished {
        if case .verified(let transaction) = verified { await transaction.finish() }
      }
      done()
    }
  }

  func testIntegration() throws {
    let session = try SKTestSession(contentsOf: storeFile)
    let ready = expectation(description: "store reset")
    try resetStore(session) { ready.fulfill() }
    wait(for: [ready], timeout: 30)
    self.session = session

    let channel = try makeChannel()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }

    var failures: [String] = []
    var ran = 0
    FLTIntegrationTestRunner().testIntegrationTest { selector, success, message in
      ran += 1
      NSLog("integration_test %@: %@", success ? "passed" : "FAILED", NSStringFromSelector(selector))
      if !success { failures.append("\(selector): \(message ?? "failed")") }
    }
    // zero results would be a green run that tested nothing
    XCTAssertGreaterThan(ran, 0, "the Dart side reported no test")
    XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
  }

  /// The Flutter view of the running app (the tests run inside it).
  private func makeChannel() throws -> FlutterMethodChannel {
    let deadline = Date().addingTimeInterval(60)
    while Date() < deadline {
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      let controller = scenes
        .flatMap { $0.windows }
        .compactMap { $0.rootViewController as? FlutterViewController }
        .first
      if let controller {
        return FlutterMethodChannel(
          name: "storekit_test", binaryMessenger: controller.binaryMessenger)
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    }
    throw NSError(domain: "RunnerTests", code: 1, userInfo: [
      NSLocalizedDescriptionKey: "no FlutterViewController in 60 seconds"
    ])
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let session else { return result(FlutterError(code: "no-session", message: nil, details: nil)) }
    let product = (call.arguments as? [String: Any])?["productId"] as? String
    do {
      switch call.method {
      case "reset":
        try resetStore(session) { result(nil) }
      case "transactions":
        Task {
          var rows: [[String: Any]] = []
          for await verified in Transaction.all {
            guard case .verified(let t) = verified else { continue }
            rows.append([
              "id": String(t.id),
              "originalId": String(t.originalID),
              "productId": t.productID,
              "expiresAt": t.expirationDate.map { Int($0.timeIntervalSince1970 * 1000) } as Any,
              "revokedAt": t.revocationDate.map { Int($0.timeIntervalSince1970 * 1000) } as Any,
            ])
          }
          result(rows)
        }
      case "sessionTransactions":
        result(session.allTransactions().map { "\($0.productIdentifier) \($0.state.rawValue) \($0.identifier)" })
      case "cancelRenewal":
        let id = (call.arguments as? [String: Any])?["id"] as? String ?? ""
        guard let number = UInt(id) else { return result(FlutterError(code: "bad-id", message: id, details: nil)) }
        try session.disableAutoRenewForTransaction(identifier: number)
        result(nil)
      case "expire":
        try session.expireSubscription(productIdentifier: product ?? "")
        result(nil)
      case "fastTime":
        // a month passes in thirty seconds
        if #available(iOS 15.2, *) {
          session.timeRate = .monthlyRenewalEveryThirtySeconds
          result(nil)
        } else {
          result(FlutterError(code: "old-ios", message: nil, details: nil))
        }
      case "refund":
        let id = (call.arguments as? [String: Any])?["id"] as? String ?? ""
        guard let number = UInt(id) else { return result(FlutterError(code: "bad-id", message: id, details: nil)) }
        try session.refundTransaction(identifier: number)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "storekit", message: "\(error)", details: nil))
    }
  }
}
