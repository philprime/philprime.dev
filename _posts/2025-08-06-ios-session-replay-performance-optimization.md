---
layout: post.liquid
title: 'Boosting Session Replay performance on iOS with View Renderer V2'
date: 2025-08-06 11:00:00 +0200
categories: blog
tags: iOS Performance Sentry Session-Replay Mobile optimization debugging
description:
  'Learn how we improved iOS Session Replay performance at Sentry with View Renderer V2, reducing overhead and making
  debugging less disruptive on older devices.'
excerpt:
  'My first post on the Sentry Blog covers investigating and improving Session Replay performance on iOS, focusing on
  making debugging less disruptive for mobile apps.'
keywords:
  'iOS performance, session replay, mobile debugging, iOS optimization, View Renderer, Sentry, mobile development,
  performance monitoring'
image: /assets/images/sentry-session-replay-og.png
author: Philip Niedertscheider
---

Proud to share that my first post on the [Sentry Blog](https://blog.sentry.io/boosting-session-replay-performance-on-ios-with-view-renderer-v2/) is now live! It covers my work on investigating and improving Session Replay performance on iOS, with a focus on making it less disruptive — especially on older devices.

## The Challenge

When Session Replay for Mobile went GA at Sentry, we saw great adoption, but users started reporting serious performance issues. iOS developers were telling us that Session Replay made their apps practically unusable on older devices — not exactly the experience we were aiming for!

As someone who cares deeply about iOS performance, I knew I had to dig into this problem. My investigation quickly revealed the culprit: main thread hangs occurring **every single second**.

## The Problem

The issue was our screenshot capture process. Each frame was taking ~155ms to render, causing 9-10 dropped frames per second — enough to make any app feel sluggish and frustrating to use.

After extensive profiling and analysis, I pinpointed the bottleneck: Apple's `UIGraphicsImageRenderer` was simply too slow.

## The Solution

Using my experience building the PDF generator framework [TPPDF](https://github.com/techprimate/TPPDF), I developed a custom `SentryGraphicsImageRenderer` that completely transformed the performance:

- **~80% reduction** in main thread blocking time (from ~155ms down to ~25ms per frame)
- Frame drops decreased dramatically from 9-10 to just ~2 frames per second
- Massive performance improvements across all iOS devices, with older hardware seeing the biggest gains

I'm proud of this work because it directly impacts thousands of iOS developers and millions of their users.

**You can read the full story on the [Sentry Blog](https://blog.sentry.io/boosting-session-replay-performance-on-ios-with-view-renderer-v2/)** with technical implementation details, benchmark results, and other insights into mobile performance optimization.
