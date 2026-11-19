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
    /// 其中「今天」記的合計（已含在 necessary／other 裡，不重複加）
    let today: Double
    var all: Double { necessary + other }

    static func make(snapshot: Snapshot, entries: [Entry]) -> UnsyncedEntries {
        let monthKey: String = snapshot.currentMonth ?? ""
        var other: Double = 0
        var necessary: Double = 0
        var today: Double = 0
        let todayKey: String = Formats.dayString(Date())
        for entry in entries {
            if snapshot.isMatched(entry) { continue }
            let isToday: Bool = entry.date == todayKey
            // 今天記的一律算（現金今天就出去了），其他日期只算快照當月
            if !monthKey.isEmpty && !entry.date.hasPrefix(monthKey) && !isToday { continue }
            if isToday { today += entry.amount }
            if entry.necessary {
                necessary += entry.amount
            } else {
                other += entry.amount
            }
        }
        return UnsyncedEntries(necessary: necessary, other: other, today: today)
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

/// v6 首頁「今天還能花」：快照今日額度 − 今天手機上記的、電腦還沒配對的合計（App 端只做加減）。
/// - 今天以前記的未配對花費，先從可動用扣掉再重算額度（可動用 ÷ 距發薪天數，無條件捨去），今天記的則直接從額度扣
/// - 今天已花＝快照今日已花（日期是今天才算）＋今天手記
/// - 圓環＝快照 today_spent_pct（沒有就沒有環）再加上手記占額度的百分比，夾在 0～100
struct TodayFigures {
    let allowance: Double
    let spentToday: Double
    let left: Double
    let ringPct: Double?

    var isOver: Bool { left < 0 }

    static func make(snapshot: Snapshot, entries: [Entry]) -> TodayFigures? {
        guard let liquid = snapshot.liquid, let base = liquid.available else { return nil }
        let unsynced: UnsyncedEntries = UnsyncedEntries.make(snapshot: snapshot, entries: entries)
        let earlier: Double = unsynced.all - unsynced.today
        var allowance: Double
        if base - earlier <= 0 {
            allowance = 0
        } else if earlier == 0, let given = liquid.dailyAllowance {
            allowance = given
        } else if let days = liquid.daysToPayday, days > 0 {
            allowance = ((base - earlier) / Double(days)).rounded(.down)
        } else if let given = liquid.dailyAllowance {
            allowance = given
        } else {
            return nil
        }
        if allowance < 0 { allowance = 0 }
        let todayKey: String = Formats.dayString(Date())
        let snapIsToday: Bool = liquid.todayDate == todayKey
        let snapSpent: Double = snapIsToday ? (liquid.todaySpent ?? 0) : 0
        let spent: Double = snapSpent + unsynced.today
        var ring: Double? = nil
        if let pct = liquid.todaySpentPct {
            let basePct: Double = snapIsToday ? pct : 0
            let extra: Double = allowance > 0 ? unsynced.today * 100 / allowance : 0
            ring = min(max(basePct + extra, 0), 100)
        }
        return TodayFigures(allowance: allowance, spentToday: spent, left: allowance - unsynced.today, ringPct: ring)
    }
}
