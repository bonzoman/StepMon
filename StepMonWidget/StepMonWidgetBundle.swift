//
//  StepMonWidgetBundle.swift
//  StepMonWidget
//
//  Created by 오승준 on 1/26/26.
//

import WidgetKit
import SwiftUI

@main
struct StepMonWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepMonWidget()
        StepMonWidgetControl()
        StepMonWidgetLiveActivity()
    }
}
