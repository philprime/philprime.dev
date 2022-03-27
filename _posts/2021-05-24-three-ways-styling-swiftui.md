---
layout: post
title: "3 ways of styling SwiftUI views"
date: 2021-05-24 17:00:00 +0200
categories: blog
---

Styling a view is the most important part of building beautiful user interfaces. When it comes to the actual code syntax, we want reusable, customizable and clean solutions in our code.

This article will show you these 3 ways of styling a SwiftUI.View:

1. Initializer-based configuration

1. Method chaining using return-self

1. Styles in the Environment

As a general rule of thumb, any approach is viable. In the end, it comes down to your general code-style guidelines and personal preferences.

![The property wrapper you will find in chapter 3 “Styles in Environment”](https://cdn-images-1.medium.com/max/7480/1*4Kk_v9ER65tuYvoK0aCeIw.png)_The property wrapper you will find in chapter 3 “Styles in Environment”_

## 1. Initializer-based configuration

This is one is straight forward and can be visualized with an example rather quickly:

<iframe src="https://medium.com/media/060a1f1b0cbdf0661201c86a8b656e51" frameborder=0></iframe>

This view takes two parameters backgroundColor and textColor, which are both required when instantiating the struct. They are also both constant let values, as the view most likely isn’t going to be mutated (at this point).

Conveniently Swift automatically synthesizes the (internal) required initializer, but they can also manually be defined be us:

<iframe src="https://medium.com/media/0066d2e55dcf99617b51168c0a641d8a" frameborder=0></iframe>
> **Quick Tip:**
Xcode also provides us with a built-in function to generate memberwise initializers. All you have to do is CMD(⌘) + left-click on the type name, and select the action.

![Xcode can automatically generate memberwise initializers](https://cdn-images-1.medium.com/max/2872/1*NptvXt3t8gt4Ay_MDhHIgg.png)_Xcode can automatically generate memberwise initializers_

Using a custom initializer allows us to add default values directly there without changing the let of the parameters to var ones:

<iframe src="https://medium.com/media/6bd29f4ed25fda0a4aa2771a3e4c6cb8" frameborder=0></iframe>

As mentioned before, Swift synthesizes only internal initializers, so in case your view is part of a package and needs to be public, you are required to use this approach. Otherwise the application using the package won’t be able to find or instantiate the view.

On the other hand, if this view is only used inside your app, you can also let the Swift compiler do the work for you 🚀 All that is needed is changing from let to var and directly set the default values on the instance properties:

<iframe src="https://medium.com/media/62e5ef1256095a4760014bb0ef052deb" frameborder=0></iframe>

## 2. Method chaining using Return-Self

Your views keep growing and requires more parameters to be set. As the initializer keeps growing too, it eventually becomes a large piece of code.

<iframe src="https://medium.com/media/5fad869b7bbb2dc6e0bbdda58240aa1f" frameborder=0></iframe>

However, from my personal experience at some point the Swift compiler has too much work to do at the same time and simply gives up (it crashes).

One approach of breaking down large initializers (with default values) is using a return-self-chaining pattern:

<iframe src="https://medium.com/media/74a7a6997d91b1f48c24ccbda56e0240" frameborder=0></iframe>

As the view itself is immutable, but consists out of pure data (structs are not objects), we can create a local copy with var view = self. As this is now a local variable, we can mutate it and set the action, before returning it.

## 3. Styles in the Environment

Apart from manually configuring every single view we can define a global style guide. An example might look like the following:

<iframe src="https://medium.com/media/abb3dcc70fddc200be0686bbd71e1b37" frameborder=0></iframe>

Unfortunately, this solution has a big issue:
Global static variables means, they are not customizable for different use cases (for example in an Xcode preview) 😕

Our solution is opting in for instance configuration once again:

<iframe src="https://medium.com/media/0c83cf965e4f1dd9503766db1479bca1" frameborder=0></iframe>

This looks promising, as we can now pass the style configuration into the view from where-ever we need it:

<iframe src="https://medium.com/media/b33a73994a9f948f759871348dd454a9" frameborder=0></iframe>

Quite a clean solution. But you might already be wondering “But wait! How is this a **global **solution?” and your doubts are justified! This solution requires us to pass the style down to every single view, just as in the following code snippet:

<iframe src="https://medium.com/media/98d3dfb3ab8b38deba540fce52ff7e9f" frameborder=0></iframe>

It took three passes just to get the “global” style object into the nested FooBar view. This is unacceptable. We don’t want this much unnecessary code (especially because you also strive for clean code, don’t you?).

Okay so what else could we think off? Well, how about a mix between the static and the instance solution?
All we need is a static object where we can set the style from Foo and read it from FooBar … sounds like some shared *environment*💡

SwiftUI introduced the property wrapper [@Environment](https://developer.apple.com/documentation/swiftui/environment) which allows us to read a value from the shared environment of our view🥳

As a first step, create a new EnvironmentKey by creating a struct implementing the defaultValue:

<iframe src="https://medium.com/media/aefbee8675f6e01bdf5f5e6896ab3968" frameborder=0></iframe>

Next you need to add the new environment key as an extension to the EnvironmentValues so it can be accessed from the property wrapper:

<iframe src="https://medium.com/media/159bd0e3c549209787668cc15261632a" frameborder=0></iframe>

Finally set the value using .environment(\.style, ...) in the root view and read the value using the keypath of the style in@Environment(\.style) in the child views:

<iframe src="https://medium.com/media/266e10219c6446f3779170ab27302395" frameborder=0></iframe>

Awesome! No more unnecessary instance passing and still configurable from the root view 🚀

### **Bonus: Custom Property Wrapper**

Our environment solution is already working pretty nice, but isn’t the following even cleaner?

<iframe src="https://medium.com/media/e50cb5c1be45980ac46324d2d9897c37" frameborder=0></iframe>

All you need for this beautiful syntax is creating a custom property wrapper @Theme which wraps our environment configuration and accesses the style value by a keypath.

<iframe src="https://medium.com/media/e210375f9eeba90505ed791a0c797ef7" frameborder=0></iframe>

Even better, using a View extension allows us to hide the usage of Environment entirely!

<iframe src="https://medium.com/media/b7538e422ee76c4e7786fc801d5e3fb0" frameborder=0></iframe>
> Note:
The reason the style is now called theme is quite honestly just a naming conflict of a property wrapper @Style with the struct Style. If you rename the style structure you can also use this name for the property wrapper.

## Conclusion

SwiftUI offers multiple different ways of building our view hierarchy, and we explored just a few of them. Additional options such as e.g. ViewModifier already exist, and even more will surface in the future.

At the time of writing **best** practices don’t really exist yet, as the technology is still quite new. Instead we have different **good** practices to choose from and can focus on re-usability, customizability and cleanness of our code.

If you would like to know more, checkout my other articles, follow me on [Twitter](https://twitter.com/philprimes) and feel free to drop me a DM.
You have a specific topic you want me to cover? Let me know! 😃
