import SwiftUI
import UIKit

final class PageHost: UIHostingController<AnyView> {
    var pageID = UUID()
}

/// Page turning: a 3D curl like real paper, or a flat 2D slide.
struct PagePager: UIViewControllerRepresentable {
    let pageIDs: [UUID]
    @Binding var index: Int
    let style: TurnStyle
    let gesturesEnabled: Bool
    let content: (UUID) -> AnyView

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = style == .curl
            ? UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal)
            : UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal,
                                   options: [.interPageSpacing: 28])
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        pvc.view.backgroundColor = Desk.uiColor
        pvc.isDoubleSided = false
        if pageIDs.indices.contains(index) {
            pvc.setViewControllers([context.coordinator.host(for: pageIDs[index])], direction: .forward, animated: false)
        }
        context.coordinator.lastIndex = index
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        let c = context.coordinator
        c.parent = self
        c.prune()
        pvc.gestureRecognizers.forEach { $0.isEnabled = gesturesEnabled }
        for case let scroll as UIScrollView in pvc.view.subviews { scroll.isScrollEnabled = gesturesEnabled }

        guard pageIDs.indices.contains(index), !c.transitioning else { return }
        let target = pageIDs[index]
        let shown = (pvc.viewControllers?.first as? PageHost)?.pageID
        if shown != target {
            let forward = index >= c.lastIndex
            pvc.setViewControllers([c.host(for: target)], direction: forward ? .forward : .reverse, animated: true)
        }
        c.lastIndex = index
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PagePager
        var hosts: [UUID: PageHost] = [:]
        var lastIndex = 0
        var transitioning = false

        init(_ parent: PagePager) { self.parent = parent }

        func host(for id: UUID) -> PageHost {
            if let hit = hosts[id] { return hit }
            let host = PageHost(rootView: parent.content(id))
            host.pageID = id
            host.view.backgroundColor = Desk.uiColor
            hosts[id] = host
            return host
        }

        func prune() {
            let alive = Set(parent.pageIDs)
            hosts = hosts.filter { alive.contains($0.key) }
        }

        private func neighbour(of vc: UIViewController, offset: Int) -> UIViewController? {
            guard let id = (vc as? PageHost)?.pageID, let i = parent.pageIDs.firstIndex(of: id) else { return nil }
            let j = i + offset
            return parent.pageIDs.indices.contains(j) ? host(for: parent.pageIDs[j]) : nil
        }

        func pageViewController(_ pvc: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
            neighbour(of: vc, offset: -1)
        }

        func pageViewController(_ pvc: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
            neighbour(of: vc, offset: 1)
        }

        func pageViewController(_ pvc: UIPageViewController, willTransitionTo pending: [UIViewController]) {
            transitioning = true
        }

        func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            transitioning = false
            guard completed, let id = (pvc.viewControllers?.first as? PageHost)?.pageID,
                  let i = parent.pageIDs.firstIndex(of: id) else { return }
            lastIndex = i
            parent.index = i
        }
    }
}
