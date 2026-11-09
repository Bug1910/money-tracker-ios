// 角色：算「本月剩餘」與「可動用」的小會計。
// 電腦端快照不知道手機上剛記的手動記帳（還沒被電腦配對進帳本），所以這裡先把它們扣掉，
// 讓首頁數字即時反映剛花的錢。公式本身由電腦端算好，這裡只做加減。
// - 本月剩餘（BudgetFigures）：只扣「本月、未配對、非必要」（必要的已在預算裡）
// - 可動用（LiquidFigures）：扣「本月、未配對」全部（現金已經出去了，不分必要／非必要）
import Foundation

enum BudgetStatus {
    case ok
    case warn
    case over
}

/// 手機上記了、電腦還沒配對的本月記帳合計
struct UnsyncedEntries {
    let necessary: Double
    let other: Double
    var all: Double { necessary + other }

    static func make(snapshot: Snapshot, entries: [Entry]) -> UnsyncedEntries {
        let monthKey: String = snapshot.currentMonth ?? ""
        var other: Double = 0
        var necessary: Double = 0
        for entry in entries {
            if snapshot.isMatched(entry) { continue }
            if !monthKey.isEmpty && !entry.date.hasPrefix(monthKey) { continue }
            if entry.necessary {
                necessary += entry.amount
            } else {
                other += entry.amount
            }
        }
        return UnsyncedEntries(necessary: necessary, other: other)
    }
}

struct BudgetFigures {
    /// 快照原本的「還能自由花」
    let baseLeft: Double
    /// 本月手機上記了、電腦還沒配對的非必要花費
    let unsyncedOther: Double
    /// 本月手機上記了、電腦還沒配對的必要花費
    let unsyncedNecessary: Double
    let budget: Double
    let status: BudgetStatus

    var left: Double { baseLeft - unsyncedOther }

    static func make(snapshot: Snapshot, entries: [Entry]) -> BudgetFigures? {
        guard let free = snapshot.freeMoney, let baseLeft = free.freeLeft else { return nil }
        let unsynced: UnsyncedEntries = UnsyncedEntries.make(snapshot: snapshot, entries: entries)
        let budget: Double = free.freeBudget ?? 0
        let left: Double = baseLeft - unsynced.other
        var status: BudgetStatus = .ok
        if free.status == "warn" { status = .warn }
        if free.status == "over" { status = .over }
        if left < 0 { status = .over }
        return BudgetFigures(baseLeft: baseLeft, unsyncedOther: unsynced.other, unsyncedNecessary: unsynced.necessary, budget: budget, status: status)
    }
}

/// 可動用：快照 liquid.available 再扣未配對手動記帳；沒有 liquid.available 就是 nil（首頁退回舊版）
struct LiquidFigures {
    let liquid: Snapshot.Liquid
    /// 快照算出的可動用
    let baseAvailable: Double
    /// 本月手機上記了、電腦還沒配對的全部記帳
    let unsyncedAll: Double

    var available: Double { baseAvailable - unsyncedAll }

    /// 每日額度：可動用 ÷ 距發薪天數，無條件捨去；可動用 ≤ 0 或沒有天數就 nil
    var dailyAllowance: Double? {
        guard let days = liquid.daysToPayday, days > 0, available > 0 else { return nil }
        return (available / Double(days)).rounded(.down)
    }

    static func make(snapshot: Snapshot, entries: [Entry]) -> LiquidFigures? {
        guard let liquid = snapshot.liquid, let base = liquid.available else { return nil }
        let unsynced: UnsyncedEntries = UnsyncedEntries.make(snapshot: snapshot, entries: entries)
        return LiquidFigures(liquid: liquid, baseAvailable: base, unsyncedAll: unsynced.all)
    }
}
