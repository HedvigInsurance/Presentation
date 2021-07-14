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

struct Embark: Presentable {
    func materialize() -> (UIViewController, FiniteSignal<Int>) {
        let viewController = UIViewController()
        viewController.title = "Test Continue"
        
        var numberOfTaps = 0

        let button = UIButton(type: .infoDark)
        viewController.view = button
        
        let bag = DisposeBag()
        
        return (viewController, FiniteSignal { callback in
            
            bag += button.onValue({ _ in
                numberOfTaps = numberOfTaps + 1
                
                if numberOfTaps > 5 {
                    callback(.end)
                    return
                }
                
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

struct Messages {
    func createAnotherEmbarkJourney() -> some ViewControllerJourneyPresentation {
        Presentation(Embark(), options: [.defaults, .autoPop]).journey { numberOfTaps in
            if numberOfTaps == 3 {
                PopJourney()
            }
        }
    }
    
    func createEmbarkJourney() -> some ViewControllerJourneyPresentation {
        Presentation(Embark(), options: [.defaults, .autoPop]).journey { numberOfTaps in
            if numberOfTaps > 3 {
                createAnotherEmbarkJourney()
            }
        }
    }
    
    var flow: some ViewControllerJourneyPresentation {
        Presentation(TestContinue(), style: .modal, options: [.defaults, .autoPop]).journey { value in
            switch value {
            case .oneOption:
                createEmbarkJourney().onPresent {
                    print("just presented embark")
                }.addConfiguration { p, bag in
                    p.title = "Custom title"
                }
            case .anotherOption:
                Presentation(Embark(), options: [.defaults, .autoPop]).journey { bla in
                    PopJourney()
                }
            case .thirdOption:
                Presentation(Embark(), options: [.defaults, .autoPop]).journey { bla in
                    PopJourney()
                }
            case .fourthOption:
                Presentation(Embark(), options: [.defaults, .autoPop]).journey { bla in
                    DismissJourney()
                }
            case .fifthOption:
                Presentation(Embark(), options: [.defaults, .autoPop]).journey { bla in
                    DismissJourney()
                }
            case .sixthOption:
                Presentation(Embark(), options: [.defaults, .autoPop]).journey { bla in
                    DismissJourney()
                }
            }
        }.onPresent {
            print("i just presented")
        }
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
            bag += viewController.present(flow).onValue({ hello in
                print(hello)
            })
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
