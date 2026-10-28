// 角色：看懂電腦端產生的 snapshot.json（金錢快照）。
// 這一版只取三個值：產生日期、還能自由花、總資產。
// 欄位缺少或型別不對都不讓 App 當掉，該欄就顯示「—」。
import Foundation

struct Snapshot: Decodable {
    let generatedAt: String?
    let freeMoney: FreeMoney?
    let assets: Assets?

    struct FreeMoney: Decodable {
        let freeLeft: Double?

        enum CodingKeys: String, CodingKey {
            case freeLeft = "free_left"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            freeLeft = try? c.decodeIfPresent(Double.self, forKey: .freeLeft)
        }
    }

    struct Assets: Decodable {
        let total: Double?

        enum CodingKeys: String, CodingKey {
            case total
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            total = try? c.decodeIfPresent(Double.self, forKey: .total)
        }
    }

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case freeMoney = "free_money"
        case assets
    }

    init(from decoder: Decoder) throws {
        // 最外層一定要是 JSON 物件；裡面每一欄用 try? 容錯
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try? c.decodeIfPresent(String.self, forKey: .generatedAt)
        freeMoney = try? c.decodeIfPresent(FreeMoney.self, forKey: .freeMoney)
        assets = try? c.decodeIfPresent(Assets.self, forKey: .assets)
    }
}
