import Foundation

enum CorpusLanguage {
    case chinese
    case english
}

// Deterministic RNG (xorshift32) for reproducible offline generation
private struct SeededRNG {
    private var state: UInt32
    init(seed: UInt32 = 0xC0FFEE21) { self.state = seed == 0 ? 0xC0FFEE21 : seed }
    mutating func next() -> UInt32 { // xorshift32
        var x = state
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        state = x
        return x
    }
    mutating func nextInt(_ upperBound: Int) -> Int { upperBound > 0 ? Int(next() % UInt32(upperBound)) : 0 }
    mutating func choose<T>(_ array: [T]) -> T { array[nextInt(array.count)] }
}

struct CorpusAugmentor {
    static func augment(corpus: [String: [String]], lang: CorpusLanguage, targetPerLevel: Int = 1000) -> [String: [String]] {
        var rng = SeededRNG()
        var result = corpus

        result["easy"] = augmentEasy(seed: result["easy"] ?? [], lang: lang, target: targetPerLevel, rng: &rng)
        result["medium"] = augmentMedium(seed: result["medium"] ?? [], lang: lang, target: targetPerLevel, rng: &rng)
        result["hard"] = augmentHard(seed: result["hard"] ?? [], lang: lang, target: targetPerLevel, rng: &rng)
        return result
    }

    // MARK: - Easy: common single words
    private static func augmentEasy(seed: [String], lang: CorpusLanguage, target: Int, rng: inout SeededRNG) -> [String] {
        var set = Set(seed.map { normalize($0, lang: lang) })
        var list = Array(seed)

        // Lexicons
        let nounsCN = ["杯子","书包","衣服","鞋子","帽子","牙刷","毛巾","眼镜","钥匙","钱包","雨伞","面包","鸡蛋","米饭","面条","蔬菜","水果","超市","学校","医院","公园","机场","火车","地铁","公交","路口","房间","厨房","客厅","卧室","浴室","桌布","碗","筷子","勺子","叉子","作业","作家","司机","医生","护士","学生","老师","朋友","同事","家人","邻居","孩子","爷爷","奶奶"]
        let verbsCN = ["吃","喝","看","听","读","写","学","玩","买","卖","走","跑","跳","坐","站","睡","起","开","关","带","拿","放","穿","洗","扫","拖","种","摘","拍","用"]
        let colorsCN = ["白色","棕色","紫色","粉色","灰色","橙色","金色","银色"]

        let nounsEN = ["cup","backpack","clothes","shoes","hat","toothbrush","towel","glasses","key","wallet","umbrella","bread","egg","rice","noodles","vegetable","fruit","supermarket","school","hospital","park","airport","train","subway","bus","crossroad","room","kitchen","living room","bedroom","bathroom","tablecloth","bowl","chopsticks","spoon","fork","homework","writer","driver","doctor","nurse","student","teacher","friend","coworker","family","neighbor","child","grandpa","grandma"]
        let verbsEN = ["eat","drink","watch","listen","read","write","study","play","buy","sell","walk","run","jump","sit","stand","sleep","wake","open","close","bring","take","put","wear","wash","sweep","mop","plant","pick","take photo","use"]
        let colorsEN = ["white","brown","purple","pink","gray","orange","gold","silver"]

        let pool: [String] = {
            switch lang {
            case .chinese: return nounsCN + verbsCN + colorsCN
            case .english: return nounsEN + verbsEN + colorsEN
            }
        }()

        var i = 0
        while list.count < target && i < target * 10 {
            i += 1
            let candidate = pool[rng.nextInt(pool.count)]
            let key = normalize(candidate, lang: lang)
            if !key.isEmpty && !set.contains(key) {
                set.insert(key)
                list.append(candidate)
            }
        }
        return Array(list.prefix(target))
    }

    // MARK: - Medium: simple daily sentences
    private static func augmentMedium(seed: [String], lang: CorpusLanguage, target: Int, rng: inout SeededRNG) -> [String] {
        var set = Set(seed.map { normalize($0, lang: lang) })
        var list = Array(seed)

        struct Slots { let times:[String]; let subjects:[String]; let places:[String]; let verbs:[String]; let objects:[String]; let frequencies:[String]; let activities:[String] }
        let zh = Slots(
            times: [
                "今天","现在","早上","中午","晚上","下班后","周末","假期","明天","昨天",
                "清晨","傍晚","周一","周末上午","明早","今晚","下周"
            ],
            subjects: ["我","他","她","我们"],
            places: [
                "家里","公司","学校","公园","超市","图书馆","咖啡馆","餐厅","火车站","机场",
                "药店","诊所","健身房","游泳馆","酒店","地铁站","公交站","博物馆","海边","山上"
            ],
            verbs: [
                "买","做","看","练习","整理","准备","完成","发送","阅读","打扫","修理","检查",
                "锻炼","预约","咨询","测量","取药","打包","乘坐","办理","休息","康复","旅行","徒步","游泳","登记","入住","退房","取票","换乘"
            ],
            objects: [
                "晚饭","作业","邮件","衣服","房间","票","报告","照片","包裹","课程",
                "药","处方","口罩","水杯","机票","护照","行李","预约单","体温","血压","心率","车票","门票","登机牌","房卡","泳衣","登山包"
            ],
            frequencies: ["每天","经常","有时","很少","每周","每月","偶尔"],
            activities: [
                "跑步","散步","做饭","学习","开会","购物","打电话","照顾家人",
                "去健身","看医生","预订车票","打包行李","体检","量血压","吃药","做瑜伽","游泳","徒步","骑车","旅行"
            ]
        )
        let en = Slots(
            times: [
                "today","now","in the morning","at noon","in the evening","after work","on weekends","on holiday","tomorrow","yesterday",
                "early morning","at dawn","at dusk","on Monday","this morning","tonight","next week"
            ],
            subjects: ["I","He","She","We"],
            places: [
                "at home","at the office","at school","in the park","at the supermarket","in the library","at the cafe","at the restaurant","at the station","at the airport",
                "at the pharmacy","at the clinic","at the gym","at the swimming pool","at the hotel","at the subway station","at the bus stop","at the museum","at the beach","in the mountains"
            ],
            verbs: [
                "buy","cook","watch","practice","tidy","prepare","finish","send","read","clean","fix","check",
                "exercise","book","consult","measure","pick up","pack","take","handle","rest","recover","travel","hike","swim","check in","check out","transfer"
            ],
            objects: [
                "dinner","homework","the email","clothes","the room","tickets","the report","the photo","the package","the class",
                "medicine","the prescription","a mask","a water bottle","a plane ticket","passport","luggage","the appointment","temperature","blood pressure","heart rate","a ticket","boarding pass","room card","swimsuit","hiking bag"
            ],
            frequencies: ["every day","often","sometimes","rarely","every week","every month","occasionally"],
            activities: [
                "go running","take a walk","cook","study","have a meeting","go shopping","make a call","take care of family",
                "work out","see a doctor","book tickets","pack luggage","take a health check","measure blood pressure","take medicine","do yoga","go swimming","go hiking","ride a bike","travel"
            ]
        )

        func makeZH() -> String {
            // Randomly choose from a few templates
            switch rng.nextInt(4) {
            case 0:
                return "\(zh.times.randomElement(using: &rng)) \(zh.subjects.randomElement(using: &rng)) 在 \(zh.places.randomElement(using: &rng)) \(zh.verbs.randomElement(using: &rng))\(zh.objects.randomElement(using: &rng))。"
            case 1:
                return "请\(zh.verbs.randomElement(using: &rng))\(zh.objects.randomElement(using: &rng))。"
            case 2:
                return "\(zh.subjects.randomElement(using: &rng)) \(zh.frequencies.randomElement(using: &rng)) 在 \(zh.places.randomElement(using: &rng)) \(zh.activities.randomElement(using: &rng))。"
            default:
                return "\(zh.subjects.randomElement(using: &rng)) 正在 \(zh.verbs.randomElement(using: &rng))\(zh.objects.randomElement(using: &rng))。"
            }
        }

        func makeEN() -> String {
            switch rng.nextInt(4) {
            case 0:
                return "\(en.times.randomElement(using: &rng).capitalized) \(en.subjects.randomElement(using: &rng).lowercased()) \(en.verbs.randomElement(using: &rng)) \(en.objects.randomElement(using: &rng)) \(en.places.randomElement(using: &rng))."
            case 1:
                return "Please \(en.verbs.randomElement(using: &rng)) \(en.objects.randomElement(using: &rng))."
            case 2:
                return "\(en.subjects.randomElement(using: &rng)) \(en.frequencies.randomElement(using: &rng)) \(en.activities.randomElement(using: &rng)) \(en.places.randomElement(using: &rng))."
            default:
                return "\(en.subjects.randomElement(using: &rng)) is \(gerund(en.verbs.randomElement(using: &rng))) \(en.objects.randomElement(using: &rng))."
            }
        }

        var attempts = 0
        while list.count < target && attempts < target * 20 {
            attempts += 1
            let candidate = (lang == .chinese) ? makeZH() : makeEN()
            let key = normalize(candidate, lang: lang)
            if !key.isEmpty && !set.contains(key) {
                set.insert(key)
                list.append(candidate)
            }
        }
        return Array(list.prefix(target))
    }

    // MARK: - Hard: ornate sentences with imagery
    private static func augmentHard(seed: [String], lang: CorpusLanguage, target: Int, rng: inout SeededRNG) -> [String] {
        var set = Set(seed.map { normalize($0, lang: lang) })
        var list = Array(seed)

        struct Slots { let adj:[String]; let image:[String]; let place:[String]; let action:[String]; let emotion:[String]; let metaphor:[String] }
        let zh = Slots(
            adj: ["静谧","绚烂","温柔","明澈","灿烂","幽深","轻柔","澎湃","热烈","缥缈","晶莹","瑰丽","清澈","宁静","斑斓"],
            image: ["星光","云霞","花海","潮汐","松涛","露珠","月色","微风","晨光","晚霞","流萤","雪影"],
            place: ["山谷","湖畔","林间","城巷","原野","海岸","庭院","桥头","小径","草坡"],
            action: ["流转","起伏","呢喃","轻落","摇曳","闪烁","铺陈","掠过","漫延","洒落"],
            emotion: ["心醉","屏息","沉迷","安然","欢欣","动容","暖意","希冀","释怀","畅然"],
            metaphor: ["犹如一幅慢慢展开的长卷","仿佛在耳畔诉说旧梦","像是把时间熬成了温柔","好似将夜色揉进了眼眸","恰如清泉缓缓入心"]
        )
        let en = Slots(
            adj: ["serene","radiant","tender","lucid","brilliant","profound","gentle","surging","ardent","ethereal","crystalline","splendid","tranquil","vivid"],
            image: ["starlight","clouds aflame","a sea of flowers","tides","pine waves","dewdrops","moonlight","breeze","dawn glow","sunset glow","fireflies","snow shadows"],
            place: ["the valley","the lakeside","the woods","the city lane","the wilds","the shore","the courtyard","the old bridge","the path","the hillside"],
            action: ["drift","rise and fall","whisper","alight","sway","glimmer","unfurl","glide","meander","pour"],
            emotion: ["breathtaking","spellbound","at peace","joyful","moved","warmed","hopeful","unburdened","unfolding calm"],
            metaphor: ["like a scroll slowly unrolling","as if old dreams were spoken by the wind","as though time simmered into tenderness","as if night were kneaded into the eyes","like a spring that quietly enters the heart"]
        )

        func makeZH() -> String {
            switch rng.nextInt(3) {
            case 0:
                return "夜色如墨，\(zh.adj.randomElement(using: &rng))的\(zh.image.randomElement(using: &rng))在\(zh.place.randomElement(using: &rng))间\(zh.action.randomElement(using: &rng))，令人\(zh.emotion.randomElement(using: &rng))。"
            case 1:
                return "清风徐来，\(zh.image.randomElement(using: &rng))在阳光下\(zh.action.randomElement(using: &rng))，\(zh.metaphor.randomElement(using: &rng))。"
            default:
                return "在\(zh.place.randomElement(using: &rng))，\(zh.adj.randomElement(using: &rng))的故事悄然生长，\(zh.image.randomElement(using: &rng))\(zh.action.randomElement(using: &rng))，叫人\(zh.emotion.randomElement(using: &rng))。"
            }
        }

        func makeEN() -> String {
            switch rng.nextInt(3) {
            case 0:
                return "The night is ink-dark, where \(en.adj.randomElement(using: &rng)) \(en.image.randomElement(using: &rng)) \(en.action.randomElement(using: &rng)) across \(en.place.randomElement(using: &rng)), leaving one \(en.emotion.randomElement(using: &rng))."
            case 1:
                return "A gentle breeze arrives; \(en.image.randomElement(using: &rng)) \(en.action.randomElement(using: &rng)) under the sun, \(en.metaphor.randomElement(using: &rng))."
            default:
                return "In \(en.place.randomElement(using: &rng)), a \(en.adj.randomElement(using: &rng)) story takes root; \(en.image.randomElement(using: &rng)) \(en.action.randomElement(using: &rng)), leaving hearts \(en.emotion.randomElement(using: &rng))."
            }
        }

        var attempts = 0
        while list.count < target && attempts < target * 25 {
            attempts += 1
            let candidate = (lang == .chinese) ? makeZH() : makeEN()
            let key = normalize(candidate, lang: lang)
            if !key.isEmpty && !set.contains(key) {
                set.insert(key)
                list.append(candidate)
            }
        }
        return Array(list.prefix(target))
    }

    // MARK: - Helpers
    private static func normalize(_ text: String, lang: CorpusLanguage) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        // Remove punctuation and lowercase for EN; remove common punctuation for ZH
        let punctuation = CharacterSet(charactersIn: ".,!?;:\"'()[]{}，。！？；：（）【】《》—…· “”‘’")
        let components = trimmed.components(separatedBy: punctuation)
        let joined = components.joined(separator: " ").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        switch lang {
        case .english:
            return joined.lowercased()
        case .chinese:
            return joined
        }
    }

    private static func gerund(_ verb: String) -> String {
        // naive English gerund maker
        var v = verb
        if v.hasSuffix("e") && !v.hasSuffix("ee") { v.removeLast() }
        return v + "ing"
    }
}

// Deterministic randomElement using seeded RNG
private extension Array {
    func randomElement(using rng: inout SeededRNG) -> Element { self[rng.nextInt(self.count)] }
}
