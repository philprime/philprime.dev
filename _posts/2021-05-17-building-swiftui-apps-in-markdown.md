---
layout: post
title: "Building SwiftUI apps in Markdown"
date: 2021-05-17 17:00:00 +0200
categories: blog
---

When your iOS app uses Markdown documents, why can’t we just transform them into natives view? What if instead of writing Swift UI code, we build a custom viewer app, which can even be run from Xcode Live Preview Canvas?

Just look at what you can do with it:

![Demo showing live Markdown to SwiftUI teasing this article](https://cdn-images-1.medium.com/max/2000/1*aC12NB2cxLzk1dEKhU-Urw.gif)_Demo showing live Markdown to SwiftUI teasing this article_

In this story we are going to cover the following topics:

1. Parsing Markdown into an AST

1. The Resolver/Strategy Pattern

1. Building an UI from resolved nodes

1. Conclusion

In case you want to see the full library, checkout the GitHub repository [CoolDown](https://github.com/techprimate/CoolDown), our own Markdown parser @ techprimate.com, which also includes a work-in-progress library _CDSwiftUIMapper._

## Parsing Markdown into a AST Node Tree

It’s highly recommended that you read my previous article “_Creating your own Markdown Parser from Scratch in Swift_” as we will reuse concepts from there.
[**Creating your own Markdown Parser from Scratch in Swift**
*Markdown is used by many platforms on a daily basis. In this tutorial you will learn how to implement your own custom…*link.medium.com](https://link.medium.com/p4VuywNzagb)

Anyway here is a short recap of the explained concepts:

1. Markdown documents consist out of blocks (separated by empty lines), which further consist out of fragments (separated by newline characters), which are made up of inline elements (such as text or bold words).

1. After parsing, the document can be represented as an abstract syntax tree (AST). The tree elements are from now one considered as _nodes_.

1. When converting a document from Markdown to SwiftUI, it goes through four stages: Styled Markdown (only for visual help) → Raw Markdown → AST/Node Tree → SwiftUI Views

Usually an example is easier to understand, so please take a look at the following one:

<iframe src="https://medium.com/media/7adc8a670e4b3fd71cee07e1acb062f0" frameborder=0></iframe>

The styling is done by GitHub Gists. The actual raw document looks like the following:

<iframe src="https://medium.com/media/af5cd4f0fccdc2a7a12c905e61720fa4" frameborder=0></iframe>

Now when parsing the document using the markdown parser (in my case it’s CoolDown), the AST reprsentation looks like the following:

<iframe src="https://medium.com/media/0b93db37a30b9801f67a7085a32cc874" frameborder=0></iframe>

Perfect! Three of our four steps are quite simple to understand, now let’s get into the last step: converting the AST nodes into SwiftUI views.

## The Resolver/Strategy Pattern

When parsing our tree, we have to think of a mapping function:

> every single kind of node will have its own view representation.
> mapping: node → view

As an example, the list node from the previous code snippet, might be mapped to the following SwiftUI view code:

<iframe src="https://medium.com/media/2887bda8712fe675d1abe2a030870940" frameborder=0></iframe>

As you can see, each node is mapped to a view structure:

- .list becomes a VStack view

- .bullet becomes a HStack view, with a Text("-") as the first element

- .text becomes a Text view

It is necessary to add a mapping function for every single node type, and manage it in an efficient way. The easiest way to do so is creating a mapper class, which takes an _array of nodes as the input_, manages a _set of mapping functions_ and *outputs a SwiftUI view *structure.

For all you (aspiring) computer scientists out there, the applied software pattern is also called the [Strategy pattern](https://en.wikipedia.org/wiki/Strategy_pattern), as the function always has the same signature, but differs in its implementation.
[**Strategy pattern - Wikipedia**
*In computer programming, the strategy pattern (also known as the policy pattern) is a behavioral software design…*en.wikipedia.org](https://en.wikipedia.org/wiki/Strategy_pattern#/media/File:Strategy_Pattern_in_UML.png)

In this article I will call them Resolver and they are defined like this:

<iframe src="https://medium.com/media/8c5662285eda765019368a424922e948" frameborder=0></iframe>

You might be wondering, what is going on, so here a quick overview:

- The mapping function takes a generic Node as an input. As we require nodes to subclass ASTNode that can be added as a generic constraint.

- We don’t know what kind of view it will return therefore the output is a generic type Result.

- Using typealias we can know use the keyword Resolver in our library

The different resolvers are managed in a mapper class:

<iframe src="https://medium.com/media/6f3596a8728a59b5904befce5e0d6750" frameborder=0></iframe>

The resolvers dictionary is a one-to-one map of different node type identifiers, to their corresponding mapping functions.

For this initial implementation, we decided to simply go with a String(describing: nodeType) as the identifier, which converts the Swift type into a String, e.g. String(describing: SwiftUI.Text.self) becomes "Text".
A much cleaner approach would be adding a static identifier to ASTNode which needs to be overwritten in every subclass. (“Hey Siri, remind me of static identifiers”).

During the implementation of this class we also hit the first limitation:

Which Result type should I use for the resolvers return value? One resolver might return SwiftUI.Text while others might even return a custom view. It is also not possible to use the super type View as it is a protocol and the compiler will start to complain:

![](https://cdn-images-1.medium.com/max/2980/1*sElta448vLw04Pop4s6lxQ.png)

Unfortunately I couldn’t find a more elegant solution (yet), other than type erasing. Therefore it uses AnyView which wraps any SwiftUI view into an untyped view structure.

A great feature of the addResolver function, is strong generic typing outside the library, such as this example mapper:

<iframe src="https://medium.com/media/b3ff38bbf60dcc0deddc6872b37d9651" frameborder=0></iframe>

## Building an UI from resolved nodes

At this point we have successfully parsed our document into a node structure, with a mapping utility ready for being filled with resolvers.

Our first resolver is the one for list which contains a list of nodes. A simple resolver to get to the desired VStack structure would be the following:

<iframe src="https://medium.com/media/96306630b5f3665deac35284612c5576" frameborder=0></iframe>

This is a great example of the so calledContainerNode, a node which contains more nested ones. We iterate each nested node mapper.resolve(node: node) which takes care of looking up the necessary resolver. In the class CDSwiftUIMapper mentioned above, you have probably noticed the fatalError("not implemented"). This is a great time to implement them:

<iframe src="https://medium.com/media/09ca64e87b3b2fb46573ccfb60fd9fd0" frameborder=0></iframe>

The function resolve takes the nodes set in the mapper during creation and resolves each one into an AnyView and combines them in an ForEach.
If it misses a node resolver, it returns a warning text, as crashes should be avoided and are super hard to debug in Xcode Previews.

As a final step (to get to the original GIF at the beginning) add we add a new view MarkdownViewer which converts the input parameter text into nodes and after mapping wraps them in a ScrollView:

<iframe src="https://medium.com/media/8fc75541f7588f947fa9fe7fceb06f8d" frameborder=0></iframe>

Combine everything together and you have created a markdown viewer in SwiftUI! 🚀

![Preview of the markdown live editing demo](https://cdn-images-1.medium.com/max/6140/1*wMp_YgdOkjExmTjVVqdU_Q.png)_Preview of the markdown live editing demo_

## Conclusion

Isn’t this cool? It is possible to build SwiftUI apps using Markdown 🤯 How practical this approach is, well, you can decide that yourself.

Here a few thoughts on what’s next:

- The framework CoolDown and its SwiftUI mapping library is still quite incomplete, therefore there is some work to do.

- Erasing all typing still seems like a bad idea, especially when SwiftUI uses diffing mechanism to re-render only relevant parts of the UI. We will look further into it, to find a better solution.

- My goal is adding a default resolver for every node type available, so the library eventually becomes plug-and-play to preview Markdown in an UI.

- When working with interactive elements, such as a web link (e.g. [follow @philprimes](https://twitter.com/philprimes)), we will experiment with mapping it into e.g. a Button which then on tap opens an associated Safari view, loading the URL.

- Currently the MarkdownViewer parses the document every single time the view gets updated, which is **very bad** for the performance. One solution would be caching the parsed nodes in a cache (maybe even in the @Environment).

- I am still experimenting with different resolvers. One major one is combining multiple TextNode nodes into a single one, so they work like a single line of text. Leave a star and/or watch the [GitHub repository](https://github.com/techprimate/CoolDown) to stay updated ⭐️

If you would like to know more, checkout my other articles, follow me on [Twitter](https://twitter.com/philprimes) and feel free to drop me a DM.
You have a specific topic you want me to cover? Let me know! 😃
