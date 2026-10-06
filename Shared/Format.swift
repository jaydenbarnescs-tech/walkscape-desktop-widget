import SwiftUI

let gold = Color(red: 1.0, green: 0.82, blue: 0.32)
let ink = Color(red: 0.06, green: 0.09, blue: 0.14)
let mint = Color(red: 0.45, green: 0.92, blue: 0.62)

func fmt(_ n: Int) -> String {
    let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = ","
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}
func short(_ n: Int) -> String {
    n >= 1_000_000 ? String(format: "%.2fM", Double(n) / 1e6) :
    n >= 10_000 ? String(format: "%.0fk", Double(n) / 1e3) :
    n >= 1_000 ? String(format: "%.1fk", Double(n) / 1e3) : "\(n)"
}
