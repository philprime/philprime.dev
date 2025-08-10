---
layout: post.liquid
title: 'Advanced cross-platform apps using local Swift packages and UIKit/AppKit'
date: 2021-04-19 17:00:00 +0200
categories: blog
tags: Swift UIKit AppKit cross-platform SPM Swift-Package-Manager iOS macOS XIB architecture
description:
  'Learn to build advanced cross-platform iOS/macOS apps using local Swift Package Manager packages with UIKit and
  AppKit. Master modular architecture with shared UI logic and platform-specific interfaces.'
excerpt:
  'Discover how to create sophisticated cross-platform iOS and macOS applications using Swift Package Manager with UIKit
  and AppKit. This advanced tutorial covers modular architecture, shared UI logic, and platform-specific interface
  building.'
keywords:
  'cross-platform apps, UIKit AppKit, Swift Package Manager, iOS macOS development, modular architecture, XIB interface
  builder, iOS development, macOS development'
image: /assets/blog/advanced-cross-platform-apps-uikit-appkit/header.png
author: Philip Niedertscheider
---

Before the release and hype of SwiftUI we had to use plain UIKit for iOS and AppKit for the macOS interfaces... even if
the core application was exactly the same. Naturally your cross-platform applications keep growing over time, and
eventually you get to the point of refactoring the code into modules.

This tutorial shows you, how to harness the impressive power of the Swift Package Manager (SPM) to create a clean,
extensible and especially shared UI structure for your large-scale apps.

![Combining Swift files with XIB interface builder files into packages](/assets/blog/advanced-cross-platform-apps-uikit-appkit/header.png)

**Note:** _This is a follow-up tutorial to_ [Modularize Xcode Project using local Swift
Packages]({% post_url 2021-04-12-modularize-xcode-projects-using-local-swift-packages %}) _and builds up on the topics
mentioned there. In case you are already an advanced iOS/macOS/SPM user, go ahead, but if you are fairly new to the
topic, I highly recommend you read my other article first._

> **Swift Development Series:** This tutorial is part of my comprehensive Swift Package Manager series. After mastering
> these concepts, you might want to explore [5 Swift Extensions to write Smarter > > >
> Code]({% post_url 2021-05-03-five-swift-extension-smarter-code %}) and [Why You Should Strongly-Type Your > >
> Localizations with Swiftgen]({% post_url 2021-05-31-strongly-type-localizations-swiftgen %}) for additional iOS
> development best practices.

## Backstory on UI building in Swift & Xcode

At the time of writing, four main options of building user interfaces exist:

1. **Plain code:** You have full control over the UI elements, the Auto Layout engine and the connected logic... without
   any hidden magic. On the other hand it is a lot more verbose and harder to iterate, especially without a live
   preview.
2. **Single view interface builder (XIB/NIB):** Visual building with full support for Auto Layout, IB Outlets and IB
   Designables to connect the UI with the code. It takes away a lot of pain and can be wired up with the application
   quite nicely. _Important side note_: macOS and iOS XIB are NOT the same!
3. **Multi view interface builder (Storyboard):** Same features as the interface builders and additionally allows to
   link multiple views together using navigation segues. _Important side note:_ macOS and iOS storyboards are NOT the
   same!
4. _SwiftUI DSL (we won’t cover it in this article, as it is not quite production-ready for large-scale apps with
   backwards-compatibility requirements)_

From my personal experience, storyboards are great for the initial development. Especially due to the simple view
navigation using segues you can get a prototype running rather quickly. Over time more views get added and eventually
Xcode starts struggling with rendering/processing/compiling the file. Slowly it starts to become more painful to work
with (don’t get me started talking about dealing with merge-conflicts with those multi-thousands lines of XML
configuration).

It gets even worse, when you just want to iterate a single view, but the large storyboard keeps changing multiple ones
(e.g. due to layout updates). Or when it takes forever updating every single view again and again, when working with
IBDesignables.

Oh, you don’t feel like navigating to a very nested sub view every. single. time? You want to use only that single view
from the storyboard in a different app target? Of course you can always dequeue it, but make sure to include all
necessary assets (even those you aren’t using right now), or otherwise it might fail to compile/run. 🙃

So… how can we improve our workflow? We go back to simpler UI building!

## Creating our Clock apps

In this tutorial we are going to build a simple clock app with the following requirements:

- iOS & macOS app
- No SwiftUI (use UIKit/AppKit)
- Modular, extensible architecture
- Show the current time in a single view
- Time updates manually when user interacts with the app

As you can see this is a (stupidly) simple app, but the main focus is using the Swift Package Manager for building UI
components, so it will suffice.

As the first step, create an **empty Xcode project** as our starting point and name it **Clock**:

![](/assets/blog/1_6L0tYZXaidggJYnkTf0gvA.png)

![Creating an empty Xcode project named Clock](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_nNutLukkYpZh92rIIqdUPg.png)

Now you have a clean starting point and inside the project settings you need to add the iOS and the macOS app targets by
clicking the little **plus symbol in the bottom left corner**:

![Adding new targets to the Xcode project can be done by clicking the plus symbol](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_pqO153yJeYzbXegWqByIsQ.png)

For the iOS target, use the default **App** template with the **UIKit App Delegate Lifecycle** and name it `Clock_iOS`.

> For the bundle identifier, use your own reverse-domain, e.g. for me it’s _com.techprimate_ because of my mobile app
> agency’s domain [techprimate.com](http://techprimate.com)

![](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_krhSZUjaNvQ9i52AfrvPSA.png)

![Creating an iOS app target in Xcode with UIKit App Delegate Life Cycle](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_PglYpVkqlHTRtXMbkTRDyg.png)

Similarly for the macOS app, use the default **App** template with the **AppKit App Delegate Lifecycle** and name it
_Clock_macOS_. As before, use your own organization identifier:

![](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_k7W8oEMR8rsNBUEg6YUxdw.png)

![Creating a macOS app target in Xcode with AppKit App Delegate Life Cycle](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_lafZan5r0aTcPqsKxZEvzA.png)

In the final project setup step, disable automatic code signing (we don’t need it right now, and usually it messes up
your Apple Developer Account by creating unwanted provisioning profiles and app identifiers). You should still be able
to run the the macOS application, with the setting **Sign To Run Locally**, and the iOS app in the simulator.

![](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_CMTulrn5C_QJwFdv81kJ7A.png)

![Settings for disabling code signing](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_R_LPWJYhrSxR49GACPqBSw.png)

Congratulations on creating your cross-platform app _Clock_! Run both applications at least once to make sure they work
fine. No worries, both screens will be a white void, as there is no UI to show yet, but we are going to fix that next.

## Creating the shared UI library

As the clock logic must be shared by both applications, we create a local Swift package library ClockPackage and drag it
into our Xcode project. Detailed step-by-step instructions can be found in [my previous
article]({% post_url 2021-04-12-modularize-xcode-projects-using-local-swift-packages %}).

```bash
$ cd root/of/my/project
$ mkdir ClockPackage
$ cd ClockPackage
$ swift package init --type library
```

Afterwards your project should look like this:

![Xcode project after adding the Swift package *ClockPackage*](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_9doVToPPrgjfDmR7V-cT-Q.png)

For simplicity, rename the `ClockPackage` target to `ClockUI` by changing the folder name and the declaration in the
package manifest Package.swift. Also, we won’t use tests in this tutorial, so go ahead and delete the folder Tests and
the test targets.

![Package configuration after cleanup](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_UgzwcX1eV269jou1QpwYcg.png)

## Adding XIB resources (the wrong way)

Now that our UI package is set up, you will create the XIB interface builder files. Both applications should offer the
user a button to update the current time and display it in a label.

While using this SPM concept in one of the iOS/macOS projects at [WolfVision](https://wolfvision.com), I realized that
XIB interface files for macOS and iOS are not interchangeable. To visualize my experiences to you, we will now do it the
wrong way and fix it afterwards.

Since Swift 5.3 it is possible to add resources to a Swift package. Apple created a
[pretty detailed documentation](https://developer.apple.com/documentation/swift_packages/bundling_resources_with_a_swift_package)
on how to handle them, but for the sake of the tutorial I will give you the quick summary:

1.  Create a folder Resources inside `Sources/ClockUI`

    ![Folder structure after adding the resources folder](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_KCmgeU23OwgszWy5SRaC7w.png)

    _Folder structure after adding the resources folder_

2.  Create an iOS View `ClockViewController_iOS.xib`

    ![Select the template ‘View’ in the iOS category](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_RKaaIEWTSgSxzC-gJDxwEQ.png)

3.  Create a macOS View `ClockViewController_macOS.xib`

    ![Select the template ‘View’ in the macOS category](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_GejsjhB6xbM6wEv0GAHroQ.png)

4.  Add both files as resources to the package manifest in the _targets_ section:

    ```swift
    ...
    targets: [
        .target(name: "ClockUI", resources: [
            .process("Resources/ClockViewController_iOS.xib"),
            .process("Resources/ClockViewController_macOS.xib"),
        ])
    ]
    ...
    ```

As you can see here, we use `process(path: String)` to compile the XIB files at build time into NIB files, which are
then used at runtime for loading the UI.

To test the compilation of the package, select ClockUI as the run scheme in the top toolbar in Xcode. Try to build it
once for _Any Mac_ and once for _Any iOS Device_. It will fail both times.

![Report navigator showing failed builds of ClockUI](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_xp03SLluTJo3PH6TawEloA.png)

Inside the *Report navigator *you can take a closer look at the two failed build logs. You will see that the macOS build
failed due to the iOS XIB file, and vice versa.

![Build errors due to platform specific XIB interface files](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_KKXGwRfq22ZqrDzMyesemw.png)

![Build errors due to platform specific XIB interface files](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_bB3AyFqg56aJCykPOfPmyQ.png)

As Swift packages do not support conditional resource compilation, we can’t use this exact project structure any further
and have to change our libraries.

## Adding XIB resources (the right way)

Create two additional libraries `ClockUI_iOS` and `ClockUI_macOS` with a folder Resource inside each one of them.
Afterwards move the `*.xib` files into their respective one and change the Package.swift manifest to reflect our new
structure:

![Swift package structure after changing to per-platform packages](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_66Uuqyc4xfNrCnIz6eqhwA.png)

```swift
let package = Package(
    name: "ClockPackage",
    products: [
        .library(name: "ClockUI", targets: ["ClockUI"]),
        .library(name: "ClockUI_iOS", targets: ["ClockUI_iOS"]),
        .library(name: "ClockUI_macOS", targets: ["ClockUI_macOS"]),
    ],
    targets: [
        .target(name: "ClockUI"),
        .target(name: "ClockUI_iOS", resources: [
            .process("Resources/ClockViewController_iOS.xib"),
        ]),
        .target(name: "ClockUI_macOS", resources: [
            .process("Resources/ClockViewController_macOS.xib"),
        ])
    ]
)
```

Now you can build the scheme `ClockUI_iOS` for _Any iOS Device_, `ClockUI_macOS` for _Any Mac_ and `ClockUI` for both of
them successfully 🎉

## Creating the interfaces

Hope you don’t mind that I am skipping the detailed explanation of the creation of the UI interfaces inside our
iOS/macOS XIB files (there so many UIKit/AppKit tutorials out there) and instead focus on the build architecture. Of
course you can always checkout the full code in the [GitHub repository](https://github.com/philprime/ClockSPMSample).

### iOS Interface

First create a class `ClockViewController` in a new file at `ClockUI_iOS/ClockViewController.swift` with an `@IBOutlet`
for accessing the time label and an IBAction for as the target action for the button.

```swift
import UIKit

public class ClockViewController: UIViewController {

    // MARK: - IB Outlets

    @IBOutlet weak var timeLabel: UILabel!

    // MARK: - IB Actions

    @IBAction func didTapFetchButtonAction() {
        print("did tap fetch")
    }
}
```

Afterwards you need to connect the File's Owner to the view controller. Make sure the module ClockUI_iOS is selected, or
otherwise it won’t be able to resolve the class later. This also allows to connect the IBOutlet/IBAction to the code
(don’t forget to set the view outlet!!)

![XIB view controller classes are set in the File’s Owner settings](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_lzBixqXYln_q9US_3Sg4Rg.png)

Before continuing with the macOS equivalent, let’s present this interface in our iOS app. To do so, we first need to add
the `ClockUI_iOS` module as a framework to our iOS target:

![](/assets/blog/advanced-cross-platform-apps-uikit-appkit/1_Oey7k0lxpdi5C5Z2D3FE-w.png)

If you followed along nicely, you can now import `ClockUI_iOS` in the `Clock_iOS/ViewController.swift` file and create
an instance of the `ClockViewController`:

```swift
import UIKit
import ClockUI_iOS

class ViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let clockVC = ClockViewController()
        self.addChild(clockVC)
        // set a debug background color so we can see the view
        clockVC.view.backgroundColor = .orange
        clockVC.view.autoresizingMask = [
            .flexibleWidth, .flexibleHeight
        ]
        self.view.addSubview(clockVC.view)
    }
}
```

As you can see, the whole view is now orange but still empty. Instead of creating an instance of `ClockViewController`
we need to load it from the XIB file by changing the following line

```swift
...
let clockVC = ClockViewController()
// becomes
let clockVC = ClockViewController.loadFromNib()
...
```

And add the `loadFromNib()` method to the `ClockViewController`:

```swift
// MARK: - Nib Loading

public static func loadFromNib() -> ClockViewController {
    // Loads the compiled XIB = NIB file from the module
    // resources bundle. Bundle.module includes all resources
    // declared in the Package.swift manifest file
    ClockViewController(nibName: "ClockViewController_iOS",
                        bundle: Bundle.module)
}
```

Run the app again and your button and label will show up 🎉

### macOS Interface

Lucky for us, the macOS implementation works exactly the same, but with the respective macOS equivalents of classes and
modules:

Create the `ClockPackage/ClockUI_macOS/ClockViewController.swift`

```swift
public class ClockViewController: NSViewController {

    // MARK: - IB Outlets

    @IBOutlet weak var timeLabel: NSTextField!

    // MARK: - IB Action

    @IBAction func didClickFetchButtonAction(_ sender: Any) {
        print("did click fetch")
    }

    // MARK: - Nib Loading

    public static func loadFromNib() -> ClockViewController {
        ClockViewController(nibName: "ClockViewController_macOS",
                            bundle: Bundle.module)
    }
}
```

Once again, don’t forget to connect the view outlet, or it fails to instantiate the NIB.

> If Xcode is not showing you the option to link view, add it as an `@IBOutlet weak var view: NSView!` in the view
> controller Swift class and then it should show up in the Xcode Interface Builder. After linking, you can simply delete
> line and it should still work fine, as NSViewController already owns a property with that name.

1.  Connect the macOS XIB with the class
2.  Add the `ClockUI_macOS` framework to the `Clock_macOS` app target
3.  Add import `ClockUI_macOS` in `Clock_macOS/ViewController.swift`
4.  Copy the `loadFromNib` from the iOS package into the macOS package
5.  Add the view controller to the view hierarchy:

    ```swift
    import Cocoa
    import ClockUI_macOS

    class ViewController: NSViewController {

        override func viewDidAppear() {
            super.viewDidAppear()

            let clockVC = ClockViewController.loadFromNib()
            self.addChild(clockVC)
            clockVC.view.autoresizingMask = [.width, .height]
            self.view.addSubview(clockVC.view)
        }

    }
    ```

Great job! You have now a running iOS and macOS application, using interface resources from Swift packages 🚀

## Shared UI Logic

As a final step, we want to create a service which is shared between the ClockUI_iOS and ClockUI_macOS packages. As we
started off with a ClockUI package, it fits our needs perfectly, therefore rename the file `ClockUI/UI.swift` to
`ClockUI/ClockService.swift` and create a class with the same name inside:

```swift
import Foundation
import Combine

public class ClockService {

    // subject to subscribe for updates
    public var currentTime = PassthroughSubject<String, Never>()

    public init() {}

    public func updateTime() {
        let formatter = DateFormatter()
        formatter.timeStyle = .full
        currentTime.send(formatter.string(from: Date()))
    }
}
```

As explained in the previous tutorial, add ClockUI as a dependency to the `ClockUI_macOS` and `ClockUI_iOS` libraries in
the package manifest.

Quick summary on the implementation logic:

1. our service can be tasked to “update” the time
2. we use Combine as it is a modern reactive framework for subscribing time changes and update our UI

To use the service in our view controllers, create a local instance and subscribe to the currentTime publisher. As an
example, here the final iOS view controller:

```swift
import UIKit
import ClockUI
import Combine

public class ClockViewController: UIViewController {

    // MARK: - Services

    private let service = ClockService()
    private var timeCancellable: AnyCancellable!

    // MARK: - IB Outlets

    @IBOutlet weak var timeLabel: UILabel!

    // MARK: - IB Actions

    @IBAction func didTapFetchButtonAction() {
        service.fetchTime()
    }

    // MARK: - View Life Cycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        timeCancellable = service.currentTime
            .sink(receiveValue: { self.timeLabel.text = $0 })
    }

    // MARK: - Nib Loading

    public static func loadFromNib() -> ClockViewController {
        // Load the compiled XIB = NIB file from the
        // module resources bundle
        ClockViewController(nibName: "ClockViewController_iOS",
                            bundle: Bundle.module)
    }
}
```

Run both applications, and voilà... you can update the time label when pressing the button in each one, with them
behaving in the same way!

You can find the full code in the [GitHub repository](https://github.com/philprime/ClockSPMSample).

## Conclusion

We did it. We created two applications using non-compatible interfaces builders with the same UI logic.

In case you are still wondering, why one should go through the hassle of splitting the project into such fragmented
packages, let me explain further:

- Imagine your application reaches a large scale with 20, 50, 100 or even more modules. Using this highly modular
  structure, you can easily create another app target (similar to how we did it for macOS & iOS) and simply import the
  specific feature you are working on.
- The build process should become more performant, as unchanged packages are cached (_unfortunately I don’t have any
  statistics available at the moment to prove this)_
- Due to the built-in isolation of Swift packages, we have a strong
  [Separation of Concerns](https://en.wikipedia.org/wiki/Separation_of_concerns) and can work with small subsets of our
  code individually (e.g. create shared utilities with their own unit tests)
- It becomes easier to create a clean architecture, such as VIPER, where the UI rendering (View) and logic (Presenter)
  are completely abstracted using protocols/interfaces.

If you would like to know more, checkout my other articles, follow me on [Twitter](https://twitter.com/philprimes) and
feel free to drop me a DM. You have a specific topic you want me to cover? Let me know! 😃
