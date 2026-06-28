import SafariServices
import Foundation
import SwiftUI

struct Partner: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let tagline: String
    let amountRange: ClosedRange<Int>
    let termRange: ClosedRange<Int>
    let responseTime: String
    let requirements: [String]
    let strengths: [String]
    let caution: String
    let url: URL
    let color: Color
    let logoAsset: String?
    let logoURL: URL?

    func score(amount: Double, months: Double, goal: BorrowGoal) -> Int {
        var value = 0
        if amountRange.contains(Int(amount)) { value += 35 }
        if termRange.contains(Int(months)) { value += 25 }
        if category == goal.category { value += 25 }
        if goal == .simpleProfile && requirements.count <= 3 { value += 15 }
        if goal == .lowCost && tagline.localizedCaseInsensitiveContains("chi phí") { value += 15 }
        return min(value, 100)
    }
}

struct RemotePartner: Decodable {
    let id: String?
    let name: String
    let category: String
    let tagline: String
    let minAmount: Int
    let maxAmount: Int
    let minMonths: Int
    let maxMonths: Int
    let responseTime: String
    let requirements: [String]
    let strengths: [String]
    let caution: String
    let url: String
    let color: String?
    let logoAsset: String?
    let logoURL: String?

    var partner: Partner? {
        guard
            minAmount > 0,
            maxAmount >= minAmount,
            maxMonths >= minMonths,
            let parsedURL = URL(string: url),
            ["http", "https"].contains(parsedURL.scheme?.lowercased())
        else {
            return nil
        }

        return Partner(
            id: id ?? "\(name)-\(url)",
            name: name,
            category: category,
            tagline: tagline,
            amountRange: minAmount...maxAmount,
            termRange: max(3, minMonths)...max(3, maxMonths),
            responseTime: responseTime,
            requirements: requirements,
            strengths: strengths,
            caution: caution,
            url: parsedURL,
            color: Color.partnerColor(named: color),
            logoAsset: logoAsset,
            logoURL: logoURL.flatMap(URL.init(string:))
        )
    }
}

struct PartnerFeed: Decodable {
    let updatedAt: String?
    let partners: [RemotePartner]
}

@MainActor
final class PartnerStore: ObservableObject {
    @Published var partners = samplePartners
    @Published var isRefreshing = false
    @Published var lastUpdatedText = "Dữ liệu mẫu trong app"
    @Published var refreshError: String?

    private let feedURL = URL(string: "https://vt868.github.io/tienoi-remote/partners.json")

    func refresh() async {
        guard let feedURL else { return }

        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }

        do {
            let request = URLRequest(url: feedURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 12)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                throw URLError(.badServerResponse)
            }

            let feed = try JSONDecoder().decode(PartnerFeed.self, from: data)
            let parsed = feed.partners.compactMap(\.partner)
            guard !parsed.isEmpty else { throw URLError(.zeroByteResource) }

            partners = parsed
            lastUpdatedText = feed.updatedAt.map { "Cập nhật: \($0)" } ?? "Đã cập nhật từ máy chủ"
        } catch {
            refreshError = "Đang dùng dữ liệu dự phòng trong app."
        }
    }
}

enum BorrowGoal: String, CaseIterable, Identifiable {
    case fast = "Cần phản hồi nhanh"
    case lowCost = "Ưu tiên chi phí thấp"
    case simpleProfile = "Hồ sơ đơn giản"
    case smallAmount = "Khoản nhỏ ngắn hạn"

    var id: String { rawValue }

    var category: String {
        switch self {
        case .fast: "Phản hồi nhanh"
        case .lowCost: "Chi phí thấp"
        case .simpleProfile: "Hồ sơ gọn"
        case .smallAmount: "Khoản nhỏ"
        }
    }
}

struct SavedPartner: Identifiable, Codable {
    let id: UUID
    let name: String
    let openedAt: Date
}

struct SafariDestination: Identifiable {
    let id = UUID()
    let url: URL
}

struct RootView: View {
    @AppStorage("tienoi.acceptedDisclosure") private var acceptedDisclosure = false
    @State private var showingDisclosure = false

    var body: some View {
        TabView {
            CompareView()
                .tabItem { Label("So sánh", systemImage: "slider.horizontal.3") }
            CalculatorView()
                .tabItem { Label("Tính trả", systemImage: "function") }
            ChecklistView()
                .tabItem { Label("Hồ sơ", systemImage: "checklist") }
            LearnView()
                .tabItem { Label("An toàn", systemImage: "shield.checkered") }
            LegalView()
                .tabItem { Label("Minh bạch", systemImage: "doc.text") }
        }
        .tint(.brandGreen)
        .sheet(isPresented: $showingDisclosure) {
            FirstLaunchDisclosure {
                acceptedDisclosure = true
                showingDisclosure = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            showingDisclosure = !acceptedDisclosure
        }
    }
}

struct CompareView: View {
    @StateObject private var partnerStore = PartnerStore()
    @State private var amount = 5_000_000.0
    @State private var months = 6.0
    @State private var goal: BorrowGoal = .simpleProfile
    @State private var selectedPartner: Partner?

    private var rankedPartners: [Partner] {
        partnerStore.partners.sorted {
            $0.score(amount: amount, months: months, goal: goal) > $1.score(amount: amount, months: months, goal: goal)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SearchPanel(amount: $amount, months: $months, goal: $goal)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            SectionTitle("Gợi ý phù hợp")
                            Spacer()
                            if partnerStore.isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        FeedStatus(text: partnerStore.refreshError ?? partnerStore.lastUpdatedText)
                        ForEach(rankedPartners) { partner in
                            PartnerCard(
                                partner: partner,
                                score: partner.score(amount: amount, months: months, goal: goal)
                            )
                            .onTapGesture {
                                selectedPartner = partner
                            }
                        }
                    }

                    DisclosureStrip()
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Tiền Ơi")
            .task {
                await partnerStore.refresh()
            }
            .refreshable {
                await partnerStore.refresh()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await partnerStore.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Cập nhật đối tác")
                }
            }
            .sheet(item: $selectedPartner) { partner in
                PartnerDetailView(partner: partner)
            }
        }
    }
}

struct SearchPanel: View {
    @Binding var amount: Double
    @Binding var months: Double
    @Binding var goal: BorrowGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tìm lựa chọn tài chính")
                    .font(.title2.bold())
                Text("So sánh theo nhu cầu trước khi mở website đối tác.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ValueSlider(
                    title: "Số tiền tham khảo",
                    valueText: amount.vndShort,
                    value: $amount,
                    range: 500_000...50_000_000,
                    step: 500_000
                )
                ValueSlider(
                    title: "Kỳ hạn mong muốn",
                    valueText: "\(Int(months)) tháng",
                    value: $months,
                    range: 3...24,
                    step: 1
                )
            }

            Picker("Mục tiêu", selection: $goal) {
                ForEach(BorrowGoal.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.menu)
            .padding(12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(
            LinearGradient(colors: [.white, Color.green.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06))
        )
    }
}

struct ValueSlider: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.brandGreen)
            }
            Slider(value: $value, in: range, step: step)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct FeedStatus: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "antenna.radiowaves.left.and.right")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PartnerCard: View {
    let partner: Partner
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                PartnerLogoView(partner: partner, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(partner.name)
                        .font(.headline)
                    Text(partner.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(score)%")
                        .font(.headline.bold())
                    Text("phù hợp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Badge(partner.category, systemImage: "target")
                Badge(partner.responseTime, systemImage: "clock")
            }

            Text("Khoản \(partner.amountRange.lowerBound.vndShort) - \(partner.amountRange.upperBound.vndShort), kỳ hạn \(partner.termRange.lowerBound)-\(partner.termRange.upperBound) tháng")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06))
        )
    }
}

struct PartnerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var safariDestination: SafariDestination?
    @AppStorage("tienoi.openedPartners") private var openedPartnersData = Data()

    let partner: Partner

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        PartnerLogoView(partner: partner, size: 64)

                        VStack(alignment: .leading, spacing: 10) {
                            Badge(partner.category, systemImage: "sparkle")
                            Text(partner.name)
                                .font(.largeTitle.bold())
                            Text(partner.tagline)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    DetailGrid(partner: partner)

                    InfoBlock(title: "Điểm mạnh", icon: "hand.thumbsup", items: partner.strengths)
                    InfoBlock(title: "Điều kiện thường gặp", icon: "person.text.rectangle", items: partner.requirements)

                    WarningBox(text: partner.caution)

                    DisclosureStrip()

                    Button {
                        rememberOpen()
                        safariDestination = SafariDestination(url: partner.url)
                    } label: {
                        Label("Mở website đối tác", systemImage: "safari")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.brandGreen)
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Chi tiết")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .fullScreenCover(item: $safariDestination) { destination in
                SafariView(url: destination.url)
            }
        }
    }

    private func rememberOpen() {
        var saved = (try? JSONDecoder().decode([SavedPartner].self, from: openedPartnersData)) ?? []
        saved.insert(SavedPartner(id: UUID(), name: partner.name, openedAt: .now), at: 0)
        saved = Array(saved.prefix(20))
        openedPartnersData = (try? JSONEncoder().encode(saved)) ?? Data()
    }
}

struct PartnerLogoView: View {
    let partner: Partner
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(14, size * 0.24))
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)

            if let logoURL = partner.logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        logoImage(image)
                    case .failure:
                        fallbackLogo
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                    @unknown default:
                        fallbackLogo
                    }
                }
            } else if let logoAsset = partner.logoAsset {
                logoImage(Image(logoAsset))
            } else {
                fallbackLogo
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: min(14, size * 0.24)))
        .overlay(
            RoundedRectangle(cornerRadius: min(14, size * 0.24))
                .stroke(Color.black.opacity(0.06))
        )
    }

    private func logoImage(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .padding(size * 0.08)
    }

    private var fallbackLogo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(14, size * 0.24))
                .fill(partner.color.opacity(0.16))
            Text(String(partner.name.prefix(1)))
                .font(.headline.bold())
                .foregroundStyle(partner.color)
        }
    }
}

struct CalculatorView: View {
    @State private var principal = 10_000_000.0
    @State private var months = 6.0
    @State private var monthlyRate = 2.2
    @State private var serviceFee = 250_000.0

    private var monthlyPayment: Double {
        let rate = monthlyRate / 100
        guard rate > 0 else { return (principal + serviceFee) / months }
        let base = principal * rate * pow(1 + rate, months) / (pow(1 + rate, months) - 1)
        return base + serviceFee / months
    }

    private var totalPayment: Double {
        monthlyPayment * months
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ước tính khoản trả")
                            .font(.title2.bold())
                        Text("Dùng để tự kiểm tra khả năng chi trả. Kết quả không phải đề nghị vay.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    CalculatorResult(monthlyPayment: monthlyPayment, totalPayment: totalPayment)

                    VStack(spacing: 12) {
                        ValueSlider(title: "Số tiền", valueText: principal.vndShort, value: $principal, range: 500_000...50_000_000, step: 500_000)
                        ValueSlider(title: "Kỳ hạn", valueText: "\(Int(months)) tháng", value: $months, range: 3...24, step: 1)
                        ValueSlider(title: "Lãi suất tháng", valueText: String(format: "%.1f%%", monthlyRate), value: $monthlyRate, range: 0.5...3.0, step: 0.1)
                        ValueSlider(title: "Phí ước tính", valueText: serviceFee.vndShort, value: $serviceFee, range: 0...2_000_000, step: 50_000)
                    }

                    WarningBox(text: "Hãy hỏi đối tác về APR, phí phạt trả chậm, tổng tiền phải trả và ngày đến hạn trước khi đăng ký.")
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Tính trả")
        }
    }
}

struct CalculatorResult: View {
    let monthlyPayment: Double
    let totalPayment: Double

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                ResultMetric(title: "Mỗi tháng", value: monthlyPayment.vndShort, color: .brandGreen)
                Divider()
                ResultMetric(title: "Tổng trả", value: totalPayment.vndShort, color: .brandBlue)
            }
            Text("Số liệu chỉ là ước tính để tham khảo, không đại diện cho bất kỳ đối tác nào.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.06)))
    }
}

struct ResultMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChecklistView: View {
    @State private var checked: Set<String> = []

    let items = [
        "Đọc kỹ lãi, phí, APR và tổng tiền phải trả",
        "Kiểm tra website/đơn vị cho vay có thông tin pháp lý rõ ràng",
        "Không chia sẻ danh bạ, mật khẩu, mã OTP",
        "Chuẩn bị CCCD, số điện thoại chính chủ nếu đối tác yêu cầu",
        "Chỉ vay khoản có thể trả đúng hạn",
        "Lưu lại lịch thanh toán và kênh hỗ trợ"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items, id: \.self) { item in
                        Button {
                            toggle(item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: checked.contains(item) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(checked.contains(item) ? Color.brandGreen : .secondary)
                                Text(item)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                } header: {
                    Text("Trước khi mở website đối tác")
                }

                Section {
                    WarningBox(text: "Tiền Ơi không yêu cầu bạn gửi CCCD, ảnh giấy tờ, danh bạ hoặc mã OTP trong app.")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Hồ sơ")
        }
    }

    private func toggle(_ item: String) {
        if checked.contains(item) {
            checked.remove(item)
        } else {
            checked.insert(item)
        }
    }
}

struct LearnView: View {
    private let lessons = [
        Lesson(title: "APR khác gì lãi tháng?", icon: "percent", body: "APR giúp bạn nhìn tổng chi phí khoản vay theo năm, gồm lãi và một số khoản phí. Khi so sánh, hãy hỏi đối tác APR và tổng tiền phải trả."),
        Lesson(title: "Dấu hiệu cần tránh", icon: "exclamationmark.triangle", body: "Cẩn thận với bên yêu cầu phí trước, ép chuyển khoản, giữ giấy tờ, xin mã OTP hoặc hứa chắc chắn giải ngân mà không thẩm định."),
        Lesson(title: "Cách bảo vệ thông tin", icon: "lock.shield", body: "Chỉ nhập thông tin trên website chính thức của đối tác. Không gửi ảnh giấy tờ qua kênh lạ và không cấp quyền danh bạ nếu không thật sự cần."),
        Lesson(title: "Khi nào không nên vay?", icon: "pause.circle", body: "Không nên vay để trả khoản vay cũ nếu bạn chưa có kế hoạch dòng tiền rõ ràng. Hãy ưu tiên khoản nhỏ, kỳ hạn vừa sức và lịch trả minh bạch.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(lessons) { lesson in
                        LessonCard(lesson: lesson)
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("An toàn")
        }
    }
}

struct LegalView: View {
    @AppStorage("tienoi.openedPartners") private var openedPartnersData = Data()

    private var openedPartners: [SavedPartner] {
        (try? JSONDecoder().decode([SavedPartner].self, from: openedPartnersData)) ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Vai trò của Tiền Ơi") {
                    Text("Tiền Ơi là ứng dụng tham khảo và so sánh thông tin đối tác tài chính. Chúng tôi không phải đơn vị cho vay, không quyết định phê duyệt, hạn mức, lãi suất hoặc giải ngân.")
                    Text("Chúng tôi có thể nhận hoa hồng giới thiệu khi bạn mở liên kết hoặc đăng ký qua website đối tác. Điều này không làm thay đổi chi phí của bạn.")
                }

                Section("Quyền riêng tư") {
                    Text("Phiên bản này không thu CCCD, ảnh giấy tờ, danh bạ, vị trí, tài khoản ngân hàng hoặc mã OTP trong app.")
                    Text("App chỉ lưu cục bộ trên thiết bị danh sách đối tác bạn đã mở để bạn tự theo dõi. Dữ liệu này không được gửi về máy chủ của Tiền Ơi.")
                }

                Section("Đã mở gần đây") {
                    if openedPartners.isEmpty {
                        Text("Chưa mở website đối tác nào.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(openedPartners) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                Text(item.openedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Minh bạch")
        }
    }
}

struct FirstLaunchDisclosure: View {
    let accept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.brandGreen)

            Text("Trước khi bắt đầu")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 12) {
                DisclosureLine("Tiền Ơi giúp tham khảo và so sánh đối tác tài chính.")
                DisclosureLine("Chúng tôi không trực tiếp cho vay hoặc phê duyệt hồ sơ.")
                DisclosureLine("Liên kết đối tác có thể là liên kết affiliate.")
                DisclosureLine("Không gửi CCCD, danh bạ, vị trí hoặc mã OTP trong app.")
            }

            Spacer()

            Button(action: accept) {
                Text("Tôi đã hiểu")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.brandGreen)
        }
        .padding(24)
        .background(Color.appBackground)
    }
}

struct DisclosureLine: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.brandGreen)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DetailGrid: View {
    let partner: Partner

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                MiniStat(title: "Khoản", value: "\(partner.amountRange.lowerBound.vndShort)-\(partner.amountRange.upperBound.vndShort)", icon: "banknote")
                MiniStat(title: "Kỳ hạn", value: "\(partner.termRange.lowerBound)-\(partner.termRange.upperBound) tháng", icon: "calendar")
            }
            GridRow {
                MiniStat(title: "Phản hồi", value: partner.responseTime, icon: "clock")
                MiniStat(title: "Nhóm", value: partner.category, icon: "tag")
            }
        }
    }
}

struct MiniStat: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.brandBlue)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct InfoBlock: View {
    let title: String
    let icon: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)
                    Text(item)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct WarningBox: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.brandAmber)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.brandAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct DisclosureStrip: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.brandBlue)
            Text("Tiền Ơi có thể nhận hoa hồng giới thiệu. Chúng tôi không phải bên cho vay và không cam kết phê duyệt.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct Badge: View {
    let text: String
    let systemImage: String

    init(_ text: String, systemImage: String) {
        self.text = text
        self.systemImage = systemImage
    }

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.05), in: Capsule())
    }
}

struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Lesson: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let body: String
}

struct LessonCard: View {
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: lesson.icon)
                    .frame(width: 32, height: 32)
                    .background(Color.brandGreen.opacity(0.12), in: Circle())
                    .foregroundStyle(Color.brandGreen)
                Text(lesson.title)
                    .font(.headline)
            }
            Text(lesson.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.06)))
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(Color.brandGreen)
        controller.modalPresentationStyle = .fullScreen
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension Color {
    static let appBackground = Color(red: 0.96, green: 0.97, blue: 0.95)
    static let brandGreen = Color(red: 0.07, green: 0.57, blue: 0.29)
    static let brandBlue = Color(red: 0.12, green: 0.36, blue: 0.74)
    static let brandAmber = Color(red: 0.88, green: 0.55, blue: 0.08)
    static let brandRose = Color(red: 0.78, green: 0.18, blue: 0.32)

    static func partnerColor(named name: String?) -> Color {
        switch name?.lowercased() {
        case "blue": .brandBlue
        case "amber", "yellow": .brandAmber
        case "rose", "red": .brandRose
        default: .brandGreen
        }
    }
}

extension Double {
    var vndShort: String {
        Int(self).vndShort
    }
}

extension Int {
    var vndShort: String {
        if self >= 1_000_000 {
            let millions = Double(self) / 1_000_000
            if millions.rounded() == millions {
                return "\(Int(millions))tr"
            }
            return String(format: "%.1ftr", millions)
        }
        return "\(self.formatted())đ"
    }
}

let samplePartners: [Partner] = [
    Partner(
        id: "vayvnd",
        name: "VayVND",
        category: "Hồ sơ gọn",
        tagline: "Nền tảng kết nối nhu cầu tài chính với đối tác phù hợp.",
        amountRange: 500_000...20_000_000,
        termRange: 3...12,
        responseTime: "Trong ngày",
        requirements: ["Có số điện thoại liên hệ", "Có thông tin cá nhân chính xác", "Đọc điều khoản đối tác trước khi đăng ký"],
        strengths: ["Có thông tin khuyến cáo và điều khoản", "Không tự nhận là tổ chức tín dụng", "Phù hợp nhu cầu khoản nhỏ đến vừa"],
        caution: "VayVND là nền tảng trung gian. Điều kiện cuối cùng, lãi, phí và giải ngân do đối tác/nhà đầu tư quyết định.",
        url: URL(string: "https://go.leadgid.com/aff_c?aff_id=91603&offer_id=5721")!,
        color: .brandGreen,
        logoAsset: "PartnerVayVND",
        logoURL: nil
    ),
    Partner(
        id: "vaymeo",
        name: "VayMèo",
        category: "Chi phí thấp",
        tagline: "Hiển thị APR 0-36% và thời hạn hoàn trả tối thiểu 91 ngày.",
        amountRange: 500_000...30_000_000,
        termRange: 3...4,
        responseTime: "Nhanh",
        requirements: ["Chọn số tiền dự kiến", "Cung cấp thông tin cơ bản trên website đối tác", "Xem kỹ đề xuất trước khi tiếp tục"],
        strengths: ["Có disclosure không phải bên cho vay", "Có APR và kỳ hạn rõ", "Dịch vụ so sánh miễn phí cho người dùng"],
        caution: "VayMèo giới thiệu đề xuất từ đối tác. Hồ sơ, hợp đồng và điều kiện cuối cùng thực hiện trên website đối tác.",
        url: URL(string: "https://go.leadgid.com/aff_c?aff_id=91603&offer_id=7065")!,
        color: .brandBlue,
        logoAsset: "PartnerVayMeo",
        logoURL: nil
    ),
    Partner(
        id: "cashspace",
        name: "Cashspace",
        category: "Phản hồi nhanh",
        tagline: "So sánh đề xuất đối tác với khoản từ 500.000đ.",
        amountRange: 500_000...20_000_000,
        termRange: 3...4,
        responseTime: "15 phút tham khảo",
        requirements: ["Chọn số tiền cần tham khảo", "Điền thông tin trên website đối tác", "Đọc kỹ tổng chi phí trước khi quyết định"],
        strengths: ["Có thông tin APR tối đa 36%", "Có kỳ hạn 91-120 ngày", "Có điều khoản và chính sách bảo mật"],
        caution: "Cashspace không trực tiếp cấp khoản vay. Điều kiện cuối cùng do đối tác trên website quyết định.",
        url: URL(string: "https://go.leadgid.com/aff_c?aff_id=91603&offer_id=5881")!,
        color: .brandAmber,
        logoAsset: "PartnerCashspace",
        logoURL: nil
    )
]

#Preview {
    RootView()
}
