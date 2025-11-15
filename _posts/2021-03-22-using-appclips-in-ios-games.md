---
layout: post.liquid
title: 'Using App Clips in iOS Games'
date: 2021-03-22 17:00:00 +0200
categories: blog
tags: iOS game App-Clips deep-links NFC QR-codes mobile-games instant-apps
description:
  'Learn how to implement App Clips in iOS games to provide instant access to gameplay without full app downloads. This
  tutorial covers deep links, QR codes, and marketing strategies for mobile games.'
excerpt:
  'Discover how to use iOS App Clips in mobile games to let users play instantly without downloading the full app. Learn
  about deep linking, QR codes, NFC tags, and creating engaging instant game experiences.'
keywords:
  'iOS App Clips, mobile games, instant apps, deep links, QR codes, NFC tags, iOS game development, App Clip marketing,
  puzzle games'
image: /assets/blog/using-appclips-in-ios-games/image-1.jpeg
author: Philip Niedertscheider
---

With the release of iOS 14, App Clips were introduced, to give users instant access to your mobile iOS app
functionality.

[Tip Tap Color 2](https://techprimate.com/tiptapcolor) is a mind-challenging, vibrant and color-blind accessible puzzle
game for your everyday distraction, created by us at [techprimate.com](https://techprimate.com)

After our initial release, when it came to new features, we decided to combine our puzzle game with the App Clip
experience.

Just a short summary of what App Clips are:

> App Clips are a great way for users to quickly access and experience what your app has to offer. An App Clip is a
> small part of your app that’s discoverable at the moment it’s needed. App Clips are fast and lightweight so a user can
> open them quickly. — Apple, [App Clips](https://developer.apple.com/app-clips)

This is a great opportunity for every developer to make their apps more accessible.

Two restrictions apply:

1. **Your App Clip can’t be larger than 10 MB**, therefore chop up your code into smaller packages and include only
   what's necessary.
2. **Your App Clip is a subset of the original app**, therefore they shall not give the user features which are not
   included in the full app.

So now that I gave you a basic introduction, let me tell you how we applied this concept to
[Tip Tap Color 2](https://techprimate.com/tiptapcolor).

We decided to use App Clips to give users the chance to play a single level of the game, without the need of looking it
up or downloading the app from the App Store. As these can also be triggered using NFC Tags and QR Codes, it has been a
great marketing opportunity too (just ask a person to scan your code with their phone, and they can immediately play
your game, genius right?).

Lucky for us, the App Clips always work the same, and only the configuration data (aka the level) changes 🚀

In the first prototype, we only had a single App Clip feature: _Random Level._

When scanning the QR Code or holding your phone against an NFC tag, it will download the 3.5 MB App Clip, launch it, and
show the In-Game view ready to play a random one of the **200 levels**!

This is great for testing them out, but soon later I realized, a random level is not the ideal way of introducing a new
person to the game. One time the random selection, chose level 198, which is one of the hardest ones… definitely the
wrong level to start off the game.

You might be wondering now: “So why does it make such a big difference if the level is easy or hard? Don’t you have like
a tutorial in there?”. That is a fair question, and to answer it correctly: Not really, but kind of yes.

### Introducing something new without actually teaching it

For this game, we decided to use the tutorial-free approach. Instead of a tutorial, the amazing level design by Julian
(UX/UI, Co-Founder @techprimate) allows users to start with a very easy single-move level, which teaches the main game
mechanic: swipe to move tiles.

The next levels introduce more complexity, like row- and column constraints for single colors. Later on, the levels get
multiple colors per row and column, so the difficulty keeps growing.

Now back to App Clips for introducing new players to the game. After a brainstorming session, we decided to add
different difficulties to the level selection:

- “easy random level” is one of 10–30
- “medium random level” is one of 30–50
- “hard random level” is one of 150–200

Additionally, we added a “beginner App Clip” feature, which always selects level 3, which is fairly simple, but not a
single swipe (after all it is for marketing purposes, so one can still explain the swiping if not self-explanatory).

### But how do App Clips work on a technical level?

Deep. Links. (and a sprinkle of magic dust ✨)

Wait, you haven’t heard of deep links before? In my opinion, they are awesome! Just think of them as a guide to a
specific place in your apps. But in a single line of characters.

**Example:**
[https://techprimate.com/tiptapcolor?level=random&difficulty=easy](https://techprimate.com/tiptapcolor?level=random&difficulty=easy*)

If you open up this link in a browser it will open our product website. But if you pack it in a QR Code and use the iOS
14 camera/QR Code scanner, it will detect the App Clip open that one instead. Just try it out:

![QRCode App Clip with a deep link to easy level in Tip Tap Color 2](/assets/blog/using-appclips-in-ios-games/qrcode-deeplink.png)

_QRCode App Clip with deep-link to easy level in Tip Tap Color 2_

To do this, it is necessary to cross-link the app and the domain, therefore add the correct app configuration to your
website and associate the domain in the app (I won’t go into detail here, but you can
[contact us](https://techprimate.com/contact), if you want us to help you in-depth).

Now we added the different difficulties **easy**, **medium** and hard as different options, and a level **beginner** in
the deep link parsing framework inside the app.

Feel free to try them out!!

Thank you so much for reading! If you would like to know more, follow me on [Twitter](https://twitter.com/philprimes)
and send me a DM with “App Clips let me play instantly!”

![App Clip QR-Codes for beginner, medium-random and hard-random level of Tip Tap Color 2](/assets/blog/using-appclips-in-ios-games/qrcodes.png)

_App Clip QR-Codes for beginner, medium-random, and hard-random level of Tip Tap Color 2_
