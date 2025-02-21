---
layout: post.liquid
title: 'Building SwiftUI apps in Markdown'
date: 2021-05-17 17:00:00 +0200
categories: blog
---

When your iOS app uses Markdown documents, why can’t we just transform them into natives view? What if instead of
writing Swift UI code, we build a custom viewer app, which can even be run from Xcode Live Preview Canvas?

Just look at what you can do with it:

![Demo showing live Markdown to SwiftUI teasing this article](/assets/blog/building-swiftui-apps-in-markdown/1_aC12NB2cxLzk1dEKhU-Urw.gif)

In this story we are going to cover the following topics:

1. Parsing Markdown into an AST
2. The Resolver/Strategy Pattern
3. Building an UI from resolved nodes
4. Conclusion

In case you want to see the full library, checkout the GitHub repository
[CoolDown](https://github.com/techprimate/CoolDown), our own Markdown parser at [techprimate](https://techprimate.com),
which also includes a work-in-progress library `CDSwiftUIMapper.`

## Parsing Markdown into a AST Node Tree

It’s highly recommended that you read my previous article [_"Creating your own Markdown Parser from Scratch in
Swift"_]({% post_url 2021-05-11-creating-own-markdown-parser-swift %}) as we will reuse concepts from there.

Anyway here is a short recap of the explained concepts:

1. Markdown documents consist out of blocks (separated by empty lines), which further consist out of fragments
   (separated by newline characters), which are made up of inline elements (such as text or bold words).
2. After parsing, the document can be represented as an abstract syntax tree (AST). The tree elements are from now one
   considered as _nodes_.
3. When converting a document from Markdown to SwiftUI, it goes through four stages: Styled Markdown (only for visual
   help) → Raw Markdown → AST/Node Tree → SwiftUI Views

Usually an example is easier to understand, so please take a look at the following one:

{% gist e34b4cf5182224e594a8db368b176961 %}

The styling is done by GitHub Gists. The actual raw document looks like the following:

```md
# My _awesome_ article

This is a simple markdown document with **bold** and _cursive_ text.

Also here is a simple bullet list:

- My first list item
- Another list item
```

Now when parsing the document using the markdown parser (in my case it’s CoolDown), the AST reprsentation looks like the
following:

```swift
let nodes: [ASTNode] = [
    .header(depth: 1, nodes: [
        .text("My "),
        .cursive("awesome"),
        .text(" article")
    ]),
    .paragraph(nodes: [
        .text("This is a simple markdown document with "),
        .bold("bold"),
        .text(" and "),
        .cursive("cursive"),
        .text(" text.")
    ]),
    .paragraph(nodes: [
        .text("Also here is a simple bullet list:")
    ]),
    .list(nodes: [
        .bullet(nodes: [
            .text("My first list item")
        ]),
        .bullet(nodes: [
            .text("Another list item")
        ])
    ])
]
```

Perfect! Three of our four steps are quite simple to understand, now lets get into the last step: converting the AST
nodes into SwiftUI views.

## The Resolver/Strategy Pattern

When parsing our tree, we have to think of a mapping function:

```
every single kind of node will have its own view representation.
mapping: node → view
```

As an example, the list node from the previous code snippet, might be mapped to the following SwiftUI view code:

```swift
VStack {
    HStack(alignment: .top) {
        Text("-")
        Text("My first list item")
    }
    HStack(alignment: .top) {
        Text("-")
        Text("Another list item")
    }
}
```

As you can see, each node is mapped to a view structure:

- `.list` becomes a `VStack` view
- `.bullet` becomes a `HStack` view, with a `Text("-") `as the first element
- `.text` becomes a `Text` view

It is necessary to add a mapping function for every single node type, and manage it in an efficient way. The easiest way
to do so is creating a mapper class, which takes an _array of nodes as the input_, manages a _set of mapping functions_
and *outputs a SwiftUI view *structure.

For all you (aspiring) computer scientists out there, the applied software pattern is also called the
[Strategy pattern](https://en.wikipedia.org/wiki/Strategy_pattern), as the function always has the same signature, but
differs in its implementation. [**Strategy pattern - Wikipedia**

In this article I will call them Resolver and they are defined like this:

```swift
public typealias Resolver<Node: ASTNode, Result> = (Node) -> Result
```

You might be wondering, what is going on, so here a quick overview:

- The mapping function takes a generic Node as an input. As we require nodes to subclass `ASTNode` that can be added as
  a generic constraint.
- We don’t know what kind of view it will return therefore the output is a generic type Result.
- Using typealias we can know use the keyword `Resolver` in our library

The different resolvers are managed in a mapper class:

```swift
public class CDSwiftUIMapper {

    // MARK: - Properties
    private let nodes: [ASTNode]
    private var resolvers: [String: Resolver<ASTNode, AnyView>] = [:]

    // MARK: - Initializer
    public init(from nodes: [ASTNode]) {
        self.nodes = nodes
    }

    // MARK: - Accessors
    public func resolve() throws -> AnyView {
        fatalError("not implemented")
    }

    public func resolve(node: ASTNode) -> AnyView {
        fatalError("not implemented")
    }

    // MARK: - Modifiers
    public func addResolver<Node: ASTNode, ElementView: View>(for nodeType: Node.Type, resolver: @escaping (CDSwiftUIMapper, Node) -> ElementView) {
        resolvers[String(describing: nodeType)] = { node in
            guard let node = node as? Node else {
                preconditionFailure("Internal resolver mismatch, expected node type does not match modifier type. This should never be called.")
            }
            return AnyView(resolver(self, node))
        }
    }
}
```

The resolvers dictionary is a one-to-one map of different node type identifiers, to their corresponding mapping
functions.

For this initial implementation, we decided to simply go with a `String(describing: nodeType)` as the identifier, which
converts the Swift type into a `String`, e.g. `String(describing: SwiftUI.Text.self)` becomes `Text`. A much cleaner
approach would be adding a static identifier to `ASTNode` which needs to be overwritten in every subclass. (“Hey Siri,
remind me of static identifiers”).

During the implementation of this class we also hit the first limitation:

Which Result type should I use for the resolvers return value? One resolver might return `SwiftUI.Text` while others
might even return a custom view. It is also not possible to use the super type View as it is a protocol and the compiler
will start to complain:

![](/assets/blog//building-swiftui-apps-in-markdown/1_sElta448vLw04Pop4s6lxQ.png)

Unfortunately I couldn’t find a more elegant solution (yet), other than type erasing. Therefore it uses AnyView which
wraps any SwiftUI view into an untyped view structure.

A great feature of the addResolver function, is strong generic typing outside the library, such as this example mapper:

```swift
let mapper = CDSwiftUIMapper(from: nodes)
mapper.addResolver(for: TextNode.self) { mapper, node in
    Text(node.content) // node has type TextNode
        .fixedSize(horizontal: false, vertical: true)
}
mapper.addResolver(for: BoldNode.self) { mapper, node  in
    Text(node.content) // node has type BoldNode
        .bold()
        .fixedSize(horizontal: false, vertical: true)
}
```

EDIT 18.09.2022: Using type-erasure was never the best implementation.Instead use `@ViewBuilder` and `switch` to resolve
all mappings.

## Building an UI from resolved nodes

At this point we have successfully parsed our document into a node structure, with a mapping utility ready for being
filled with resolvers.

Our first resolver is the one for list which contains a list of nodes. A simple resolver to get to the desired VStack
structure would be the following:

```swift
mapper.addResolver(for: ListNode.self) { mapper, node  in
    VStack(alignment: .leading) {
        ForEach(node.nodes, id: \.self) { node in
            mapper.resolve(node: node)
        }
    }
}
```

This is a great example of the so called `ContainerNode`, a node which contains more nested ones. We iterate each nested
node mapper `.resolve(node: node)` which takes care of looking up the necessary resolver. In the class `CDSwiftUIMapper`
mentioned above, you have probably noticed the `fatalError("not implemented")`. This is a great time to implement them:

```swift
public func resolve() throws -> AnyView {
    AnyView(
        ForEach(nodes, id: \.self) { node in
            self.resolve(node: node)
        }
    )
}

public func resolve(node: ASTNode) -> AnyView {
    guard let resolver = resolvers[String(describing: type(of: node))] else {
        return AnyView(Text("Missing resolver for node: " + node.description))
    }
    return resolver(node)
}
```

The function resolve takes the nodes set in the mapper during creation and resolves each one into an AnyView and
combines them in an `ForEach`. If it misses a node resolver, it returns a warning text, as crashes should be avoided and
are super hard to debug in Xcode Previews.

As a final step (to get to the original GIF at the beginning) add we add a new view MarkdownViewer which converts the
input parameter text into nodes and after mapping wraps them in a ScrollView:

```swift

import SwiftUI
import CoolDownParser
import CoolDownSwiftUIMapper

struct MarkdownViewer: View {

    let nodes: [ASTNode]

    init(_ text: String) {
        self.nodes = CDParser(text).nodes
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 25)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var content: some View {
        do {
            let mapper = CDSwiftUIMapper(from: transform(nodes: nodes))
            mapper.addResolver(for: TextNode.self) { mapper, node in
                Text(node.content) // node has type TextNode
                    .fixedSize(horizontal: false, vertical: true)
            }
            // add more resolvers here
            return try mapper.resolve()
        } catch {
            return AnyView(Text(error.localizedDescription))
        }
    }
}
```

Combine everything together and you have created a markdown viewer in SwiftUI! 🚀

![Preview of the markdown live editing demo](/assets/blog/building-swiftui-apps-in-markdown/1_wMp_YgdOkjExmTjVVqdU_Q.png)

## Conclusion

Isn’t this cool? It is possible to build SwiftUI apps using Markdown 🤯 How practical this approach is, well, you can
decide that yourself.

Here a few thoughts on what’s next:

- The framework CoolDown and its SwiftUI mapping library is still quite incomplete, therefore there is some work to do.
- Erasing all typing still seems like a bad idea, especially when SwiftUI uses diffing mechanism to re-render only
  relevant parts of the UI. We will look further into it, to find a better solution.
- My goal is adding a default resolver for every node type available, so the library eventually becomes plug-and-play to
  preview Markdown in an UI.
- When working with interactive elements, such as a web link (e.g.
  [follow @philprimes](https://twitter.com/philprimes)), we will experiment with mapping it into e.g. a Button which
  then on tap opens an associated Safari view, loading the URL.
- Currently the MarkdownViewer parses the document every single time the view gets updated, which is **very bad** for
  the performance. One solution would be caching the parsed nodes in a cache (maybe even in the @Environment).
- I am still experimenting with different resolvers. One major one is combining multiple TextNode nodes into a single
  one, so they work like a single line of text. Leave a star and/or watch the
  [GitHub repository](https://github.com/techprimate/CoolDown) to stay updated ⭐️

If you would like to know more, checkout my other articles, follow me on [Twitter](https://twitter.com/philprimes) and
feel free to drop me a DM. You have a specific topic you want me to cover? Let me know! 😃
