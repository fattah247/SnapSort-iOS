//
//  LoadingView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import SwiftUI

struct LoadingView: View {
    var message: String = "Loading"
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)

                // Animated ring
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AppColors.primaryGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            }

            Text(message)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Loading Overlay Modifier
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String

    func body(content: Content) -> some View {
        ZStack {
            content

            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                LoadingView(message: message)
                    .padding(AppSpacing.xl)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
            }
        }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String = "Loading") -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}

#Preview {
    LoadingView(message: "Curating your memories")
}
