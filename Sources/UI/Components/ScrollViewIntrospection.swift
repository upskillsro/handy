import SwiftUI
import AppKit

struct ScrollConfigurator: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ScrollViewIntrospector())
    }
}

extension View {
    func configureScrollView() -> some View {
        self.modifier(ScrollConfigurator())
    }
}

struct ScrollViewIntrospector: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Optimization: Only run if not already configured
        // Check if we've found the scrollView and set its style already
        if let scrollView = nsView.enclosingScrollView, scrollView.scrollerStyle == .overlay {
            return
        }
        
        // Fallback or Initial Setup
        DispatchQueue.main.async {
            if let scrollView = nsView.enclosingScrollView {
                // Apply ONLY if state doesn't match to avoid thrashing
                if scrollView.scrollerStyle != .overlay {
                    scrollView.scrollerStyle = .overlay
                    scrollView.hasVerticalScroller = false
                    scrollView.hasHorizontalScroller = false
                    scrollView.drawsBackground = false
                }
            }
        }
    }
}
