import SwiftUI

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    @ViewBuilder let content: () -> Content

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.bounces = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let hosting = UIHostingController(rootView: AnyView(content()))
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        scrollView.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        context.coordinator.hostingController = hosting

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = AnyView(content())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<AnyView>?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController?.view
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            scrollView.setZoomScale(1.0, animated: true)
        }
    }
}
