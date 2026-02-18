//
//  PhotoReviewWidgetsLiveActivity.swift
//  PhotoReviewWidgets
//
//  Created by Muhammad Abdul Fattah on 16/02/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PhotoReviewWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PhotoReviewWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PhotoReviewWidgetsAttributes.self) { context in
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

extension PhotoReviewWidgetsAttributes {
    fileprivate static var preview: PhotoReviewWidgetsAttributes {
        PhotoReviewWidgetsAttributes(name: "World")
    }
}

extension PhotoReviewWidgetsAttributes.ContentState {
    fileprivate static var smiley: PhotoReviewWidgetsAttributes.ContentState {
        PhotoReviewWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PhotoReviewWidgetsAttributes.ContentState {
         PhotoReviewWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PhotoReviewWidgetsAttributes.preview) {
   PhotoReviewWidgetsLiveActivity()
} contentStates: {
    PhotoReviewWidgetsAttributes.ContentState.smiley
    PhotoReviewWidgetsAttributes.ContentState.starEyes
}
