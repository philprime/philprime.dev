---
layout: post
title: "Creating your own Markdown Parser from Scratch in Swift"
date: 2021-05-11 17:00:00 +0200
categories: blog
---

You know Markdown, right? That text format which uses funky characters like , \*\* or > to create well formatted documents? Awesome! Many platforms use it on a daily basis, so you will eventually use it too.

Now, what if you need a markdown parser for your Swift application? Well, we could just use one of the well-tested ones (which can be found using your favorite search engine on GitHub), but instead… you can also create your own version.

![Drake might also prefer writing his own solution](https://cdn-images-1.medium.com/max/2000/1*S5uBWbywD4XLTwR16-cGoQ.jpeg)_Drake might also prefer writing his own solution_

All jokes aside: if possible, do not _reinvent the wheel._ If an existing framework with an active maintainer fits your needs, use that one. At [techprimate](https://techprimate.com) we decided to create our own solution, [CoolDown](https://github.com/techprimate/CoolDown), because an upcoming app uses Markdown with many custom extensions, therefore it was more convenient to have full control.

This article will also give you a general idea on how to parse a structured plain text document. Here a quick outline what we will cover:

1. Markdown Document Structure

1. Structure of a Document Parser

1. Implementing the Code

1. Parsing fragments by their characters

## Markdown Document Structure

Markdown documents are written entirely in plain text, and any additional assets are only added as URL references.

Over the years multiple Markdown specs surfaced and many platforms (e.g. GitHub) adapted and extended it. Eventually it got standardized to remove ambiguity. For this tutorial, we will use the [CommonMark 0.29](https://spec.commonmark.org/0.29/) specification as a reference, as it is quite a common one (pun intended).

### Structural Elements

A major structural element of the document is the _double-newline/empty line_, as it structures our document into a sequence of _blocks_. Just look at the following example:

<iframe src="https://medium.com/media/a937532dc51681104568da00bcd9734a" frameborder=0></iframe>

It is quite obvious that these should be considered as two blocks, but the following is only a single block:

<iframe src="https://medium.com/media/fe7a1bee2beff07788ea48f04614d863" frameborder=0></iframe>

These blocks can be categorized even further into *Leaf Block*s (e.g. headings), _Container Blocks_ (e.g. lists) and _Inlines_ (e.g. code spans). I won’t go further into detail for now, as you can just look at the detailed CommonMark documentation.

Now we need to take a closer look at a single block:

    This is a full text *with some cursive* and some **bold text**.

This is still a single block, but it consists out of 5 inline blocks/elements:

1. Plain Text: This·is·a·full·text· (including the trailing whitespace)

1. Cursive Text: with·some·cursive

1. Plain Text: ·and·some·

1. Bold Text: bold·text

1. Plain Text: .

## Structure of a Document Parser

Alright, at this point you have some basic understanding of what data we are dealing with. Now you need to know how to parse a plain text document in general. A rule of thumb:

> Break the text it into the smallest possible chunks, before processing each chunk

As mentioned before, our document consists out of a sequence of blocks. This already makes our lives way easier, as we can now analyze the blocks individually.

Next we know that none of the Markdown elements span more than a single line. Even the following example, a multi-line code segment, can be seen as three “sub-blocks”. To simplify our naming, I will from now on refer to them as* Fragments:*

<iframe src="https://medium.com/media/e3b3bde915267ebb61eaeaf63b2a7ec7" frameborder=0></iframe>

We already broke down a large document into blocks and afterwards into fragments. As the content of the individual fragments varies, we can not break it down any further.

![Markdown documents consist out of blocks, which are made up of fragments and inlines further down](https://cdn-images-1.medium.com/max/6054/1*oV75cDIooAre7oB0o4u64g.png)_Markdown documents consist out of blocks, which are made up of fragments and inlines further down_

By keeping this structure in mind we can create the following basic algorithm:

<iframe src="https://medium.com/media/321a3087206e4a05013d94277e49d1e3" frameborder=0></iframe>

## Implementing the Code

Your time has come. It’s time to write some code 🔥

As our library is entirely logic based and works as a black box (text as input, parsed document as output) this is a great use-case for **Test-Driven-Development (TDD)**.
The main idea of this development strategy is first defining a test case, which will fail on purpose, and then writing the code to fix it.

As the first step create a new Swift package **_MarkdownParser_** using either your Terminal of choice and swift package init --type library or using Xcode:

![Xcode also offers an option to create a Swift Package](https://cdn-images-1.medium.com/max/2120/1*FbgWdOyIAHKC8IjAnfvgmw.png)_Xcode also offers an option to create a Swift Package_

Next, open up MarkdownParserTests.swift and create your first test case:

<iframe src="https://medium.com/media/ebcd3fbb6ba5311e4cd032a664991549" frameborder=0></iframe>

This code is straight forward, but for the sake of the tutorial I will explain it: First define the input text, then create a parser using the input text and call parse() to convert it into a node tree. Finally we write a test assertion to check that it returns the expected result.

Xcode will usually tell you about the syntax issues rather quickly:

![Xcode will complain, but this is expected when doing Test Driven Development](https://cdn-images-1.medium.com/max/4460/1*sDvFyFqF6UOhHwCyWJuG4g.png)_Xcode will complain, but this is expected when doing Test Driven Development_

The only solution to fix this situation is implementing the class MarkdownParser which fulfills the test expectations:

<iframe src="https://medium.com/media/36d789a9001c81749c0c7646a8b99612" frameborder=0></iframe>

Run the test again and it will not fail anymore (for now\* \*foreshadowing intensifies\*\*) 🎉

### Creating our first content node

Before adding more functionality, add a new test case:

<iframe src="https://medium.com/media/eb317c7c5551847a0641f9159e33b707" frameborder=0></iframe>

Once again we need to fix our code to fulfill the expectations by adding a new content node type to our known node types

<iframe src="https://medium.com/media/23bc2e97b6e8a8e9e909df7c0d6c366b" frameborder=0></iframe>

and changing our parser to satisfy both test cases:

<iframe src="https://medium.com/media/12df27ea6a3de7e19d8181546b048e6b" frameborder=0></iframe>
> **Note:**
In this tutorial I am using an enum to define the different nodes, because of it’s simplicity. You can also create struct's or even classes to return the parsed nodes.

### Stepping up our parsing game

Alright, alright, alright… enough with the simple text parsing. By now you hopefully understand how TDD is working, so let’s jump a few steps forward and create a more advanced test case:

<iframe src="https://medium.com/media/a727c85ea3f7920860791b5d97efb536" frameborder=0></iframe>

The first step to deal with this complex example is creating the necessary node types:

<iframe src="https://medium.com/media/46ccc9c7bb591e0e226c8dbf917f8f0b" frameborder=0></iframe>

Now remember the algorithm in the introduction: First we need to split the text into blocks to then iterate them. We do this in a testable way by creating a so called Lexer , a class to split our raw content into smaller chunks (the so called _lexems_).
Additionally it implements the iterator protocol, to use a standardized looping mechanism:

<iframe src="https://medium.com/media/b7948e84d7fe1e0505a7639a254cc4a2" frameborder=0></iframe>

Our Markdown parser is growing and the first two steps of our algorithm are already implemented:

<iframe src="https://medium.com/media/3e7352bbd89e6d0ca5507c4fe7f73519" frameborder=0></iframe>

Good job with the progress! Let’s take care of step 3 and 4 next:

> 3. Split each block into fragments
> 4. Iterate all fragments and parse them into nodes (e.g. bold text)

Create another class BlockParser which will iterate every fragment in a block and parse them individually:

<iframe src="https://medium.com/media/0495bcfcb44187b16992225784d2d267" frameborder=0></iframe>

Adapt the MarkdownParser.parse() to use it for each block and finish step 3 of our algorithm:

<iframe src="https://medium.com/media/1f43506cf0d1852816037342ce648184" frameborder=0></iframe>

## Parsing fragments by their characters

Up until this point the structure of the document was well-known (blocks split by empty lines, fragments split by newline characters).

For the actual fragment parsing logic you can choose from multiple approaches (such as using Regex’s) but in this approach we are using a character-based lexer.

The fragment lexer differs from the previous ones, as it iterates the content by each character and also offers additional methods to _peak_ at further characters (does not increase the iterator counter) and _rewind_ to move the iterator backwards.

<iframe src="https://medium.com/media/c20950751e5dcec9380072bdcaf82f92" frameborder=0></iframe>

Using all the knowledge we gathered during this tutorial, let’s create the last missing parser, the FragmentParser . This class is going to use our FragmentLexer and identify the different nodes by specific characters, as declared in the specification.
In the first version, we concatenate each character into a .text(...) node to fulfill our second test case:

<iframe src="https://medium.com/media/2ab65d9eb0a715ee8b9485b4b63e3f90" frameborder=0></iframe>

This works fine for the simple use case, but for more complex use-cases we need an additional data structure to efficiently track the abstract nesting position inside the fragment.

### The Inline Stack

To understand what is going on, we think through the parsing logic of a more complex block (even more complicated than the previous ones):

    This is a text block **with bold *and cursive*** text.

Should map the following structure:

    .paragraph(nodes: [
        .text("This is a text block"),
        .bold("with bold"),
        .boldCursive("and cursive"),
        .text(" text.")
    ]),

Our fragment parsing algorithm will therefore work something like this:

<iframe src="https://medium.com/media/118a3f9af5ede426b8fe038d853b3357" frameborder=0></iframe>

Please keep in mind, this is pseudo code and should only help to understand what is going on.

Now look at the following slightly different example:

    This is a text block **with bold *and none cursive** text.

After removing the last asterisk, the parsed structure will look a bit different:

    .paragraph(nodes: [
        .text("This is a text block"),
        .bold("with bold *and none cursive"),
        .text(" text.")
    ]),

Unfortunately this also depends on our parser, as the following output could be valid too:

    .paragraph(nodes: [
        .text("This is a text block *"),
        .cursive("with bold "),
        .text("and none cursive"),
        .cursive(""),
        .text(" text."),
    ]),

This is a software design decision you have to make. In case you are curious how I implemented it, checkout the [BoldCursiveInlineSpec.swift](https://github.com/techprimate/CoolDown/blob/main/Tests/CoolDownParserTests/BoldCursiveInlineSpec.swift) of CoolDown on GitHub.

As an efficient way of tracking the nesting, I decided to use a stack, which adds an additional node on the beginning characters (such as \*\*) and removes it from the stack when the closing characters are found.

To not increase the complexity of this tutorial any further, I will not cover the exact implementation of the stack mechanism. If you want to know now more, [CoolDown](https://github.com/techprimate/CoolDown) is very well commented.

### Finishing up our parser

Alright, this is the final FragmentParser for the scope of this tutorial:

<iframe src="https://medium.com/media/2c56efb9ac13e5f0c1d9a078debb77da" frameborder=0></iframe>

The code is commented so it should be self-explanatory. In this example you can also see why our FragmentLexer has additional peak and rewind methods.

When you run the test case once again, they still fails with the following result:

<iframe src="https://medium.com/media/ca77f2b730df40bd0ff0138c229cc6a8" frameborder=0></iframe>

If you are fine with the two blocks being merged into a single one, good job, change the tests and you are done 😄

If not, change the MarkdownParser.parse() method to group the nodes per block and if more than one block was found, it shall wrap them in paragraph nodes:

<iframe src="https://medium.com/media/aadca21bbcd7516f7e7a01fee5e75ec9" frameborder=0></iframe>

## Conclusion

You made it! Congratulations 🥳

This tutorial only covered a small subset of the possibilities in using and parsing Markdown. Obviously the three tests are not enough to covert the implemented functionality, so make sure to write more tests!

I also referenced our custom parser @ techprimate called CoolDown multiple times, which is still a work-in-progress, but is eventually getting production ready. We decided to build it as an Open Source Swift package, so checkout the [GitHub repository](https://github.com/techprimate/CoolDown).

Next to actually writing a small working parser, you also got more insight into the document format itself. Now you should be able to pick it up from there and continue working on the parser.

If you would like to know more, checkout my other articles, follow me on [Twitter](https://twitter.com/philprimes) and feel free to drop me a DM.
You have a specific topic you want me to cover? Let me know! 😃
