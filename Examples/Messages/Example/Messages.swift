//
//  Messages.swift
//  Messages
//
//  Created by Måns Bernhardt on 2018-04-19.
//  Copyright © 2018 iZettle. All rights reserved.
//

import UIKit
import Flow
import Presentation

enum TestContinueResult {
    case oneOption
    case anotherOption
    case thirdOption
    case fourthOption
    case fifthOption
    case sixthOption
}

struct TestContinue: Presentable {
    func materialize() -> (UIViewController, FiniteSignal<TestContinueResult>) {
        let viewController = UIViewController()
        viewController.title = "Test Continue"
        
        let view = UIView()
        view.backgroundColor = .white
        viewController.view = view
        
        let bag = DisposeBag()
        
        return (viewController, FiniteSignal { callback in
                        
            bag += Signal(after: 2).onValue {
                callback(.value(.oneOption))
            }
            
            return bag
        })
    }
}

struct TestDisposableResult: Presentable {
    func materialize() -> (UIViewController, Disposable) {
        let viewController = UIViewController()
        viewController.title = "Test disposable"
        
        let view = UIView()
        view.backgroundColor = .white
        viewController.view = view
        
        let bag = DisposeBag()
        
        bag += {
            print("i was disposed")
        }
        
        return (viewController, bag)
    }
}

struct TestFutureResult: Presentable {
    func materialize() -> (UIViewController, Future<Void>) {
        let viewController = UIViewController()
        viewController.title = "Test disposable"
        
        let button = UIButton()
        viewController.view = button
        
        button.setTitle("Close", for: .normal)
        
        let bag = DisposeBag()
        
        return (viewController, Future { completion in
            
            bag += button.onValue { _ in
                completion(.success)
            }
            
            return bag
        })
    }
}

struct EmbarkState: Codable {
    var numberOfTaps: Int = 0
}

enum EmbarkAction {
    case updateNumberOfTaps(_ taps: Int)
}

final class EmbarkStore: Store {
    let providedSignal: ReadWriteSignal<EmbarkState>
    
    let onAction = Callbacker<EmbarkAction>()
        
    func reduce(_ state: EmbarkState, _ action: EmbarkAction) -> EmbarkState {
        var newState = state
        
        switch action {
            case let .updateNumberOfTaps(taps):
                newState.numberOfTaps = taps
        }
        
        return newState
    }
    
    func effects(_ state: EmbarkState, _ action: EmbarkAction) -> Future<EmbarkAction>? {
        nil
    }
    
    init() {
        if let stored = Self.restore() {
            providedSignal = ReadWriteSignal(stored)
        } else {
            providedSignal = ReadWriteSignal(State())
        }
    }
}


struct Embark: Presentable {
    func materialize() -> (UIViewController, FiniteSignal<Int>) {
        let viewController = UIViewController()
        viewController.title = "Test Continue"
        
        let embarkStore: EmbarkStore = get()

        let button = UIButton(type: .infoDark)
        viewController.view = button
        
        let bag = DisposeBag()
        
        return (viewController, FiniteSignal { callback in
            bag += button.withLatestFrom(embarkStore.atOnce().plain()).onValue({ _, state in
                let numberOfTaps = state.numberOfTaps + 1
                embarkStore.send(EmbarkAction.updateNumberOfTaps(numberOfTaps))
                
                callback(.value(numberOfTaps))
            })
            
            return bag
        })
    }
}

struct EndOfJourney: Presentable {
    func materialize() -> (UIViewController, Future<Void>) {
        let viewController = UIViewController()
        viewController.title = "end this is"

        let button = UIButton(type: .detailDisclosure)
        viewController.view = button
        
        let bag = DisposeBag()
        
        return (viewController, Future { completion in
            
            bag += button.onValue({ _ in
                completion(.success)
            })
            
            return bag
        })
    }
}

struct DisposableEndOfJourney: Presentable {
    func materialize() -> (UIViewController, Disposable) {
        let viewController = UIViewController()
        viewController.title = "end this is"
        
        let button = UIButton(type: .detailDisclosure)
        viewController.view = button
        
        let bag = DisposeBag()
        
        return (viewController, bag)
    }
}

enum RestorableJourneyPoints: String, RestorableJourneyPointIdentifier {
    case start = "start"
    case createAnotherEmbarkJourney = "createAnotherEmbarkJourney"
}

struct Messages {
    static func createAnotherEmbarkJourney() -> some JourneyPresentation {
        RestorableJourneyPoint(identifier: RestorableJourneyPoints.createAnotherEmbarkJourney) {
            Journey(Embark()) { numberOfTaps, context in
                Journey(TestContinue()) { value, _ in
                    Journey(TestContinue()) { value, _ in
                        Journey(TestContinue()) { value, _ in
                            DismissJourney().onPresent {
                                print("test")
                            }
                        }
                    }
                }.onPresent {
                    dump(context)
                }
            }.onValue { numberOfTaps in
                print(numberOfTaps)
            }
        }
    }
    
    static func createEmbarkJourney() -> some JourneyPresentation {
        Journey(Embark()) { numberOfTaps, context in
            ContinueJourney()
        }.onValue { numberOfTaps in
            print(numberOfTaps)
        }
    }
    
    static var flow: some JourneyPresentation {
        RestorableJourneyPoint(identifier: RestorableJourneyPoints.start) {
            Journey(TestContinue(), style: .modal) { value, _ in
                TabbedJourney(
                    {
                        createAnotherEmbarkJourney().addConfiguration { presenter in
                            presenter.viewController.tabBarItem = UITabBarItem(tabBarSystemItem: .bookmarks, tag: 1)
                        }.cancelJourneyDismiss
                    },
                    {
                        Journey(TestContinue()) { _ in
                            ContinueJourney()
                        }.addConfiguration { presenter in
                            presenter.viewController.tabBarItem = UITabBarItem(tabBarSystemItem: .downloads, tag: 2)
                        }
                    },
                    {
                        Journey(TestContinue()) { _ in
                            ContinueJourney()
                        }.addConfiguration { presenter in
                            presenter.viewController.tabBarItem = UITabBarItem(tabBarSystemItem: .featured, tag: 2)
                        }
                    },
                    {
                        Journey(TestContinue()) { _ in
                            ContinueJourney()
                        }.addConfiguration { presenter in
                            presenter.viewController.tabBarItem = UITabBarItem(tabBarSystemItem: .featured, tag: 2)
                        }
                    },
                    {
                        Journey(TestContinue()) { _ in
                            ContinueJourney()
                        }.addConfiguration { presenter in
                            presenter.viewController.tabBarItem = UITabBarItem(tabBarSystemItem: .featured, tag: 2)
                        }
                    },
                    {
                        Journey(TestContinue()) { _ in
                            ContinueJourney()
                        }.addConfiguration { presenter in
                            presenter.viewController.tabBarItem = UITabBarItem(tabBarSystemItem: .featured, tag: 2)
                        }
                    },
                    {
                        Journey(TestContinue()) { _ in
                            ContinueJourney()
                        }.addConfiguration { presenter in
                            presenter.viewController.tabBarItem = UITabBarItem(tabBarSystemItem: .featured, tag: 2)
                        }
                    }
                )
            }
        }.cancelJourneyDismiss
    }
    
    let messages: ReadSignal<[Message]>
    let composeMessage: Presentation<ComposeMessage>
    let messageDetails: (Message) -> Presentation<MessageDetails>
}

struct Message: Decodable, Equatable {
    var title: String
    var body: String
}

extension Messages: Presentable {
    func materialize() -> (UIViewController, Disposable) {
        let split = UISplitViewController()
        split.preferredDisplayMode = UIDevice.current.userInterfaceIdiom == .pad ? .allVisible : .automatic

        let viewController = UITableViewController()
        viewController.title = "Messages"

        let composeButton = UIBarButtonItem(barButtonSystemItem: .compose, target: nil, action: nil)
        viewController.navigationItem.rightBarButtonItem = composeButton

        let dataSource = DataSource()
        viewController.tableView.dataSource = dataSource

        let delegate = Delegate()
        viewController.tableView.delegate = delegate
        let selectSignal = Signal(callbacker: delegate.callbacker)

        // Setup event handling
        let bag = DisposeBag()

        bag.hold(dataSource, delegate)

        bag += split.present(viewController, options: [ .defaults, .showInMaster ])

        bag += messages.atOnce().onValue {
            dataSource.messages = $0
            viewController.tableView.reloadData()
        }

        let splitDelegate = split.setupSplitDelegate(ownedBy: bag)
        let selection = MasterDetailSelection(elements: messages, isSame: ==, isCollapsed: splitDelegate.isCollapsed)

        bag += selectSignal.onValue { indexPath in
            selection.select(index: indexPath.row)
        }

        bag += selection.presentDetail(on: split) { indexAndElement in
            if let message = indexAndElement?.element {
                return DisposablePresentation(self.messageDetails(message))
            } else {
                return DisposablePresentation(Empty())
            }
        }

        bag += selection.atOnce().delay(by: 0).onValue { indexAndElement in
            guard let index = indexAndElement?.index else { return }
            viewController.tableView.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .none)
        }

        bag += composeButton.onValue {
           
        }

        return (split, bag)
    }
}

// Setup table view data source and delegate
private class DataSource: NSObject, UITableViewDataSource {
    var messages = [Message]()

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "message") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "message")
        let message = messages[indexPath.row]
        cell.textLabel?.text = message.title
        cell.detailTextLabel?.text = message.body
        return cell
    }
}

private class Delegate: NSObject, UITableViewDelegate {
    let callbacker = Callbacker<IndexPath>()

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        callbacker.callAll(with: indexPath)
    }
}

struct Empty: Presentable {
    func materialize() -> (UIViewController, Disposable) {
        return (UIViewController(), NilDisposer())
    }
}
