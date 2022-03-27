---
layout: post
title: "5 Swift Extensions to write Smarter Code"
date: 2021-05-03 17:00:00 +0200
categories: blog
---

A good developer should write great code with high maintainability and extensibility. Even better developers extend the programming language with smart functionality that makes it easier to read and write clean code.

Let me show you 5 code extensions for Swift, which I use on a daily basis. Every single one is explained in detail and recreated from its backstory/original intent.

In case you TL;DR and only want to see the code, scroll to each **The Smart Solutions **headline for the copy-paste ready code, or checkout the link in the conclusion.

![Photo by [Norbert Levajsics](https://unsplash.com/@levajsics?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/mac?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)](https://cdn-images-1.medium.com/max/12000/1*_8zmr2ra_G7CmrJpMBY9-Q.jpeg)_Photo by [Norbert Levajsics](https://unsplash.com/@levajsics?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/mac?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)_

## 1. Safe Array access with custom subscripts

Every developer has at least once experienced an _“out-of-bounds”_ exception. These occur when you try to access an element at a position which is either negative or higher than the element count.

    let values = ["A", "B", "C"]
    values[0] // A
    values[1] // B
    values[2] // C
    values[3] // Fatal error: Index out of range

We start to create bound checks before accessing the value. That leads to repetitive code even tough it always does the exact same thing: checking the index bounds.

    if 2 < values.count {
        values[2] // "C"
    }
    if 3 < values.count {
        values[3] // won't be called
    }

Let’s create a function to wrap the bounds check, taking the element index and the array of elements as parameters. To support any kind of element, we add a generic type T. This function returns an Optional value wrapping either the element or nil if the index is out of bounds.

    func getValue<T>(in elements: [T], at index: Int) -> T? {
        guard index >= 0 && index < elements.count else {
            return nil
        }
        return elements[index]
    }

    let values = ["A", "B", "C"]
    getValue(in: values, at: 2) // "C"
    getValue(in: values, at: 3) // nil

This works fine, but it is still quite verbose and (simply said) ugly compared to the original e.g. values[2]. Especially because of the additional parameter values .

First off we want to get rid of values parameter and instead associate the function getValue with the array. As Swift supports extending classes and protocols, we can move our getValue into an extension of Array :

    extension Array {

        func getValue(at index: Int) -> Element? {
            guard index >= 0 && index < self.count else {
                return nil
            }
            return self[index]
        }
    }

    let values = ["A", "B", "C"]
    values.getValue(at: 2) // "C"
    values.getValue(at: 3) // nil

To use even more of the sweet Swift syntax capabilities, change the function to be a subscript function.

### The Smart Solution:

    extension Array {

        subscript (safe index: Int) -> Element? {
            guard index >= 0 && index < self.count else {
                return nil
            }
            return self[index]
        }
    }

    values[safe: 2] // "C"
    values[safe: 3] // nil

Awesome! Our access call values[safe: 2] looks almost identical to the original one values[2] but provides us boundary safe access to the elements.

_EDIT 04.05.2021:_

Thanks to [Daniil Vorobyev](undefined) for his response! Here a even more generic example, which can be used for any class implementing the Collection protocol:

    extension Collection {
       public subscript (safe index: Self.Index) -> Iterator.Element? {
         (startIndex ..< endIndex).contains(index) ? self[index] : nil
       }
    }

## 2. Handling nil and empty Strings equally

When working with optional values, we often need to compare them with nil for null-checking. Sometimes we use a default value, in case the value is in fact nil, to keep going.

Here an example method which returns a default value in case the parameter is nil:

    func unwrap(value: String?) -> String {
        return value ?? "default value"
    }
    unwrap(value: "foo") // foo
    unwrap(value: nil) // default value

But another edge exists too: empty Strings.

If we use this unwrap method with an empty string "" it will return the same empty String. There are definitely use-cases where we don’t want this behavior, but instead treat the empty String the same way as nil .

We have to extend our function with a length check:

    func unwrap(value: String?) -> String {
        let defaultValue = "default value"
        guard let value = value else {
            return defaultValue
        }
        if value.isEmpty {
            return defaultValue
        }
        return value
    }
    unwrap(value: "foo") // foo
    unwrap(value: "")    // default value
    unwrap(value: nil)   // default value

Quite an ugly solution for such a simple fallback, right?
So, how about compressing it into a single line of code?

    func unwrapCompressed(value val: String?) -> String {
        return val != nil && !val!.isEmpty ? val! : "default value"
    }
    unwrapCompressed(value: "foo") // foo
    unwrapCompressed(value: "") // default value
    unwrapCompressed(value: nil) // default value

It works, but neither is this solution readable nor “good” by any standards, especially when trying to avoid force-unwrapping ! (to reduce the potential of unhandled crashes).

### The Smart Solution:

Convert empty strings to nil and work with the built-in support of Optional

    public extension String {
        var nilIfEmpty: String? {
            self.isEmpty ? nil : self
        }
    }

Using this smart extension, you can use e.g. if-let unwrapping for checking for nil and for empty strings at the same time:

    var foo: String? = nil
    if let value = foo?.nilIfEmpty {
        bar(value) // not called
    }
    if let value = "".nilIfEmpty {
        bar(value) // not called
    }
    if let value = "ABC".nilIfEmpty {
        bar(value) // called with "ABC"
    }

Additionally this extension allows you to use a default value using ?? when the string is empty:

    "ABC" ?? "123"  // ABC
    "" ?? "456      // 456

## 3. Multi Assignment Operator

On iOS, interfaces are built using UIKit’s\* \*UIView’s, nested inside more UIView’s, managed by a UIWindow, eventually resulting in a view hierarchy (same for AppKit on macOS).

When developers interact with the UI, they most certainly need references to specific views, which are then stored inside instance variables.

Let’s take a look at an example view controller.

    class ViewController: UIViewController {

        private weak var someViewRef: UIView?

        override func viewDidLoad() {
            super.viewDidLoad()

            let someView = UIView()
            self.someViewRef = someView
            self.view.addSubview(someView)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)

            // Update the background on appear
            someViewRef?.backgroundColor = .red
        }
    }

First we create someView and add it to the view hierarchy in viewDidLoad. Afterwards we set a weak reference to the someViewRef instance property so we can interact with the view in viewWillAppear :

Zooming in on the detail we want to improve:

    (1) let someView = UIView()
    (2) self.someViewRef = someView
    (3) self.view.addSubview(someView)

We want to reduce these 3 lines of code, without compromising on readability. This might seem over-engineered for this small single use case, but think about a view controller where 20 or even 30 views are created → 20–30 lines of code can be saved.

To really understand what is going on, you have to know about Automatic Reference Counting (ARC).

### Automatic Reference Counting (ARC)

ARC was introduced in Objective-C as form of memory management back in iOS 5.

When creating the view in (1), some memory (enough to hold an UIView) is allocated for the instance. In the same step, an internal counter is set to 1, as someView is a reference to this instance. When assigning the someViewRef in (2) the counter increases by one. The final line (3) increases it once again (to a total count of 3), because the view hierarchy also holds a reference to the particular view.

At the end of viewDidLoad method, all local variables and references are discarded, including someView . This decrements the counter, and it is left at 2 for someViewRef and the view hierarchy (because of view.addSubview(...))

> One of the core principles of UIKit/AppKit is letting the view hierarchy be the only one holding the strong references to the views.

So in case the view gets removed from the overall view hierarchy, the counter should be decremented to 0 and automatically be freed from the memory. This helps with reducing memory leaks when navigating through an app.

To comply with this principle, we always use weak references, as they **do not increment the ARC counter**. As the view can be deallocated, and therefore the instance isn’t available anymore (it becomes nil) it needs to be an Optional type.

In the code example abovesomeViewRef is already declared as weak , and so at the end of viewDidLoad our counter value is 1 .

What happens if we combine the first two lines into a single one?

![A new instance assigned to a weak property will be deallocated immediately](https://cdn-images-1.medium.com/max/3060/1*jcOha5xBrXUB8E_B2h1eXw.png)_A new instance assigned to a weak property will be deallocated immediately_

The compiler already tells us that this statement is going to be useless. We create a new instance, but do not increment the ARC due to weak . Therefore the counter is still at 0 after executing the line of code and the instance is deallocated instantly.

Also the someViewRef is now optional, and we would need to unwrap the UIView? to add it to the parent view.

![Weak references need to be unwrapped as they are optional](https://cdn-images-1.medium.com/max/3040/1*FOAdcefJfZWPjQasJgv9PQ.png)_Weak references need to be unwrapped as they are optional_

To summarize our requirements:

1. we want to simplify the code into a single line

1. we need a local instance, so it doesn’t get deallocated immediately

1. we need an unwrapped instance, so we can add it to the view hierarchy

1. we need to use weak so the reference counter isn’t incremented

1. it should preferably be reusable for **_any object_**

Seems like a tough problem, doesn’t it?
Luckily, Swift provides many syntax features, so we can build our custom solution.

### Assignment function with side effects:

In the first step, move the assignment of someViewRef into a global function (can be anywhere). One parameter is the weak inout reference, where we assign the instance to, and the the second one is the instance of the UIView .

    func assign(someViewRef: inout Optional<UIView>,
                someView: UIView) -> UIView {
        someViewRef = someView
        return someView
    }

Our viewDidLoad can be transformed to the following:

    override func viewDidLoad() {
        super.viewDidLoad()

        let someView = assign(someViewRef: &someViewRef,
                              someView: UIView())
        self.view.addSubview(someView)
    }

Great! A single line to both create the view and assign someView and someViewRef 🎉

It is still highly limited, as it only allows UIView instances, but we can improve this by changing the parameter to be a generic type:

    func assign<T>(target: inout Optional<T>, value: T) -> T {
        target = value
        return value
    }

You can improve it even further, by changing the value parameter to be a closure returning the value (that might become interesting e.g. in case you want to use limited code scopes):

    func assign<T>(target: inout Optional<T>, value: () -> T) -> T {
        let instance = value()
        target = instance
        return instance
    }

    let someView = assign(target: &someViewRef, value: {
        let view = UIView()
        view.backgroundColor = .orange
        return view
    })

Unfortunately this breaks our previous usage:

![Values can’t be used as closure parameters (by default)](https://cdn-images-1.medium.com/max/3064/1*_g7jJ3q9BbvydAUiBGyZsA.png)_Values can’t be used as closure parameters (by default)_

We fix it by prepending the parameter type of value with @autoclosure and both are working once again 🔥

But how do you feel about these changes?

    // we started with
    let someView = UIView()
    someViewRef = someView

    // we are now at
    let someView = assign(target: &someViewRef, value: UIView())

Using & for the reference, and parameter names and etc. lead to a quite verbose line of code… but at least it is one line of code, amirite?!😅

Was it worth it? Probably not… but luckily this isn’t even its final form 🤯

### The Smart Solution:

    infix operator <--

    public func <-- <T>(target: inout T?,
                        value: @autoclosure () -> T) -> T {
        let val = value()
        target = val
        return val
    }

Rename the function from assign to a sleek arrow <-- and declare it as an infix operator (if you feel adventurous you can even use an emoji arrow ⬅️). Other examples of these infix operators are + and -. All of them take two parameters… one before, and one after the operator.

Our final solution fits all the constraints in a pretty, short syntax:

    let someView = someViewRef <-- UIView()

## 4. Filtered element counting in Arrays

How often do you count elements in an array?
What is your approach? Is it one of the following ones?

    let array = ["A", "A", "B", "A", "C"]
    // 1.
    var count = 0
    for value in array {
        if value == "A" {
            count += 1
        }
    }
    // 2.
    count = 0
    for value in array where value == "A" {
        count += 1
    }
    // 3.
    count = array.filter { $0 == "A" }.count
    // 4...
    // get creative, there are many more

Swift tries to be as human-friendly as possible, and our code should also try to reflect the human language.

So instead of filtering, counting, iterating etc. everywhere in your codebase, checkout this clean, small, universally applicable count(where:) extension (which honestly should exist in Swift standard library by default).

### The Smart Solution:

    extension Sequence where Element: Equatable {

        func count(where isIncluded: (Element) -> Bool) -> Int {
            self.filter(isIncluded).count
        }
    }

By extending the Sequence protocol, other classes than Array are supported too, such as ArraySlice :

    ["A", "A", "B"]
        .count(where: { $0 == "A" }) // 2
    ["B", "A", "B"]
        .dropLast(1) // --> ArraySlice<String>
        .count(where: { $0 == "B" }) // 1

## 5. Logic operators for SwiftUI Binding

This extension will most likely not be used as often as the others. Still it solves a struggle when working with Binding in SwiftUI.

Take the following example, showing two buttons where each one shows a different sheet:

    struct ContentView: View {

        @State var isPresentingSheet1 = false
        @State var isPresentingSheet2 = false

        var body: some View {
            VStack {
                Button("Show Sheet 1") {
                    isPresentingSheet1 = true
                }
                Button("Show Sheet 2") {
                    isPresentingSheet2 = true
                }
            }
            .sheet(isPresented: $isPresentingSheet1) {
                Text("Sheet 1")
            }
            .sheet(isPresented: $isPresentingSheet2) {
                Text("Sheet 2")
            }
        }
    }

Chaining the .sheet(isPresented:) {...} feels quite naturally. Unfortunately this wasn’t actually working for a long time and got resolved only a few days ago with the [release of iOS 14.5](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-14_5-release-notes) (still broken in previous versions).

As I wanted to use the isPresented version of .sheet() instead of .sheet(item:) (with some kind of enum declaring every single possible sheet) I tried to concatenate the two Binding<Bool> instances:

![Logical operators do not support Binding](https://cdn-images-1.medium.com/max/3064/1*1p_TsE6DF8zUSxQabbxtOA.png)_Logical operators do not support Binding_

Bummer. This was expected, but still I am not happy.

Fortunately we can overload the already existing infix operator && by simply creating a global function with the same name, but with two Binding<Bool> parameters 🚀

### The Smart Solution:

    public func && (lhs: Binding<Bool>,
                    rhs: Binding<Bool>) -> Binding<Bool> {
        Binding<Bool>(get: { lhs.wrappedValue && rhs.wrappedValue },
                      set: { _ in fatalError("Not implemented") })                       }

Binding<Bool> is a property wrapper which holds a wrappedValue: Bool . Every Binding has a getter and a setter closure, which returns a logical conjunction of the two parameters. As the setter method is undefined (which parameter should be changed?) we leave it with not implemented for now.

## Conclusion

There are many more smart extension out their in the wildness of the internet. All the ones listed here, are also available, documented and tested in my toolbox [Cabinet on GitHub](https://github.com/philprime/Cabinet).

If you would like to know more, checkout my other articles, follow me on [Twitter](https://twitter.com/philprimes) and feel free to drop me a DM.
You have a specific topic you want me to cover? Let me know! 😃

**Edits:**

04.05.2021 — Added response of [Daniil Vorobyev](undefined)
