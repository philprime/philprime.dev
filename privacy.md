---
layout: page.liquid
title: Privacy Policy
permalink: /privacy/
description: "Privacy policy for philprime.dev, including information about analytics, error monitoring, and data collection."
keywords: "privacy policy, data protection, analytics, umami, sentry"
image: /assets/images/default-og-image.png
---

## Overview

This website is a personal blog operated by Philip Niedertscheider.
Your privacy matters, and this site is designed to collect as little data as possible.

## Analytics

This site uses [Umami](https://umami.is), a privacy-focused analytics tool, to understand how visitors use the site.
Umami does not use cookies, does not collect personal data, and does not track visitors across websites.
All data is aggregated and anonymous.

The following information is collected:

- Page URL and referrer
- Browser and operating system type
- Device type (desktop, mobile, tablet)
- Visitor country (derived from IP address, which is not stored)

## Error and Performance Monitoring

Production pages use [Sentry](https://sentry.io) to detect JavaScript errors, monitor performance, and understand what happened before or during a problem.
Sentry is configured for error monitoring, performance tracing, and sampled session replay.

Depending on whether an error, trace, or sampled replay is captured, Sentry may receive technical data such as:

- Page URL, referrer, timestamp, browser, operating system, and device information
- Error messages, stack traces, source file names, line numbers, and console breadcrumbs
- Performance timing information for sampled page loads, navigation, and browser requests
- Masked replay data for sampled sessions, such as DOM structure, clicks, scrolling, network request metadata, and console entries

## Cookies

This site does not use cookies for analytics or monitoring.
Sentry Session Replay may use browser session storage to keep replay state for the current browser tab.

## Third-Party Services

This site loads scripts and styles from service providers used to operate the site, including Sentry, Umami, and CDN providers for frontend assets.
Those providers may receive standard request metadata such as IP address, requested URL, referrer, user agent, and timestamp when your browser requests their resources.

Content may occasionally embed or link to third-party services (for example GitHub or YouTube).
These services have their own privacy policies, and interacting with embedded content may be subject to their terms.

## Contact

If you have questions about this policy, you can reach me at [legal@philprime.dev](mailto:legal@philprime.dev).

## Changes

This policy may be updated from time to time.
Last updated: May 2026.
