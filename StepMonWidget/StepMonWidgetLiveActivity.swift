//
//  StepMonWidgetLiveActivity.swift
//  StepMonWidget
//
//  Created by 오승준 on 1/26/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct StepMonWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct StepMonWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StepMonWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension StepMonWidgetAttributes {
    fileprivate static var preview: StepMonWidgetAttributes {
        StepMonWidgetAttributes(name: "World")
    }
}

extension StepMonWidgetAttributes.ContentState {
    fileprivate static var smiley: StepMonWidgetAttributes.ContentState {
        StepMonWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: StepMonWidgetAttributes.ContentState {
         StepMonWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: StepMonWidgetAttributes.preview) {
   StepMonWidgetLiveActivity()
} contentStates: {
    StepMonWidgetAttributes.ContentState.smiley
    StepMonWidgetAttributes.ContentState.starEyes
}
