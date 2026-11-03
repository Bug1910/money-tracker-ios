// 角色：算「剩餘預算」的小會計。
// 電腦端快照算出的「還能自由花」不知道手機上剛記的手動記帳（還沒被電腦配對進帳本），
// 所以這裡把「本月、未配對、非必要」的手動記帳先扣掉，讓首頁數字即時反映剛花的錢。
// 公式本身（收入−必要支出−待繳−儲蓄目標−非必要支出）由電腦端算好，這裡只做加減。
import Foundation

enum BudgetStatus {
    case ok
    case warn
    case over
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
        let budget: Double = free.freeBudget ?? 0
        let left: Double = baseLeft - other
        var status: BudgetStatus = .ok
        if free.status == "warn" { status = .warn }
        if free.status == "over" { status = .over }
        if left < 0 { status = .over }
        return BudgetFigures(baseLeft: baseLeft, unsyncedOther: other, unsyncedNecessary: necessary, budget: budget, status: status)
    }
}
