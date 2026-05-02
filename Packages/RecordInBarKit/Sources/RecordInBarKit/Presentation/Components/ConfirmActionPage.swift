import SwiftUI

struct ConfirmActionPage: View {
    let icon: String
    let iconTint: Color
    let title: String
    let message: String
    let confirmLabel: String
    let confirmRole: ButtonRole?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    init(
        icon: String,
        iconTint: Color,
        title: String,
        message: String,
        confirmLabel: String,
        confirmRole: ButtonRole? = .destructive,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconTint = iconTint
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
        self.confirmRole = confirmRole
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(iconTint)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("取消") { onCancel() }
                    .font(.system(size: 12))
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button(confirmLabel, role: confirmRole) { onConfirm() }
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
