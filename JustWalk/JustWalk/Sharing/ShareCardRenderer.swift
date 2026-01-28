//
//  ShareCardRenderer.swift
//  JustWalk
//
//  Utility for rendering share card views to images and presenting share sheets
//

import SwiftUI
import MapKit
import Photos

enum ShareCardRenderer {

    // MARK: - Render View to Image

    @MainActor
    static func render<V: View>(_ view: V, size: CGSize) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = UITraitCollection.current.displayScale
        return renderer.uiImage
    }

    // MARK: - Share Image

    @MainActor
    static func shareImage(_ image: UIImage) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // Find the topmost presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        topVC.present(activityVC, animated: true)
    }

    // MARK: - Save to Photos

    static func saveToPhotos(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                DispatchQueue.main.async { completion(success) }
            }
        }
    }

    // MARK: - Route Map Snapshot

    static func renderRouteMap(coordinates: [CodableCoordinate], size: CGSize) async -> UIImage? {
        guard coordinates.count >= 2 else { return nil }

        let clCoords = coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        let latitudes = clCoords.map { $0.latitude }
        let longitudes = clCoords.map { $0.longitude }

        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4 + 0.005,
            longitudeDelta: (maxLon - minLon) * 1.4 + 0.005
        )
        let region = MKCoordinateRegion(center: center, span: span)

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.mapType = .standard
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            let image = UIGraphicsImageRenderer(size: size).image { context in
                snapshot.image.draw(at: .zero)

                let path = UIBezierPath()
                for (index, coord) in clCoords.enumerated() {
                    let point = snapshot.point(for: coord)
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }

                UIColor(red: 0x40/255, green: 0x85/255, blue: 0xFF/255, alpha: 1.0).setStroke()
                path.lineWidth = 4
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
            return image
        } catch {
            return nil
        }
    }
}
