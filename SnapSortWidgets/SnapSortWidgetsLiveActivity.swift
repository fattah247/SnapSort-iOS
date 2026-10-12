//
//  SnapSortWidgetsLiveActivity.swift
//  SnapSortWidgets
//
//  Created by Muhammad Abdul Fattah on 16/02/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SnapSortWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SnapSortWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SnapSortWidgetsAttributes.self) { context in
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

extension SnapSortWidgetsAttributes {
    fileprivate static var preview: SnapSortWidgetsAttributes {
        SnapSortWidgetsAttributes(name: "World")
    }
}

extension SnapSortWidgetsAttributes.ContentState {
    fileprivate static var smiley: SnapSortWidgetsAttributes.ContentState {
        SnapSortWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SnapSortWidgetsAttributes.ContentState {
         SnapSortWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SnapSortWidgetsAttributes.preview) {
   SnapSortWidgetsLiveActivity()
} contentStates: {
    SnapSortWidgetsAttributes.ContentState.smiley
    SnapSortWidgetsAttributes.ContentState.starEyes
}
