//
//  SimpleWalkWidgetsBundle.swift
//  SimpleWalkWidgets
//
//  Created by Randy Chia on 1/9/26.
//

import WidgetKit
import SwiftUI

@main
struct SimpleWalkWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SimpleWalkStepsWidget()
        #if os(watchOS)
        StepsRemainingWatchWidget()
        #endif
        DistanceWidget()
        #if os(iOS)
        SimpleWalkWidgetsLiveActivity()
        ClassicWalkLiveActivity()
        if #available(iOS 18.0, *) {
            WalkControlWidget()
        }
        #endif
    }
}
