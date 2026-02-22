import SwiftUI
import AppKit

struct WindowDragHandler: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView {
        return DragView()
    }
    
    func updateNSView(_ nsView: DragView, context: Context) {}
    
    class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        
        override func mouseDown(with event: NSEvent) {
            self.window?.performDrag(with: event)
        }
    }
}
