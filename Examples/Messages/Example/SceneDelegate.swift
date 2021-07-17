//
//  SceneDelegate.swift
//  Example
//
//  Created by Sam Pettersson on 2021-07-17.
//  Copyright © 2021 iZettle. All rights reserved.
//

import Foundation
import UIKit
import Flow

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    let bag = DisposeBag()
    var window: UIWindow?
    
    static var mainActivityType: String {
        // Load the activity type from the Info.plist.
        let activityTypes = Bundle.main.infoDictionary?["NSUserActivityTypes"] as? [String]
        return activityTypes![0]
    }
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {        
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            self.window = window
            window.makeKeyAndVisible()
            
            if let activity = session.stateRestorationActivity, let journeyPoint: RestorableJourneyPoints = activity.journeyPoint() {
                scene.userActivity = activity
                scene.title = activity.title
                
                switch journeyPoint {
                case .createAnotherEmbarkJourney:
                    bag += window.present(Messages.createAnotherEmbarkJourney())
                case .start:
                    bag += window.present(Messages.flow)
                }
            } else {
                scene.userActivity = NSUserActivity(activityType: Self.mainActivityType)
                scene.title = scene.userActivity?.title
                bag += window.present(Messages.flow)
            }
        }
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }
}
