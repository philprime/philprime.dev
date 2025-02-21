---
layout: post.liquid
title: iOS Push Notifications, but without user authentication!
date: 2021-03-29 17:00:00 +0200
categories: blog
tags: iOS
---

Push Notifications allow developers to send small messages directly to a user's device, without actively polling for
changes inside the app. Now when it comes to external notifications, sometimes it might not even be possible to contact
an iOS device, as they are not reachable from the internet.

![iPhone showing two examples of Push Notifications](/assets/blog/ios-push-notifications-without-user-auth/image-1.jpeg)

_iPhone showing two examples of Push Notifications_

While working on my latest CI/CD app [kiwi](https://techprimate.com/kiwi), one of the most requested features is
real-time notifications when a build status changes. It’s time for a small excursion to explain, what the purpose of
this app is, and why Push Notifications are pretty much the only viable solution for updates:

GitHub, GitLab, Bitrise, and others are offering **C**ontinuous **I**ntegration and **C**ontinous **D**elivery services,
which allow us to automate tasks in combination with using a Git versioning control system (VCS). Now when a developer
pushes their changes from their computer to the code repository, the VCS provider (e.g. GitHub) notifies the CI/CD
service to run some tasks for the given changes. Often these tasks are scripts used to create build products from the
software code, which is why the terms are used interchangeably.

It is also possible that the VCS and CI/CD are operated by different providers, such as storing the code on GitHub, but
using Bitrise as the CI/CD service. When using multiple providers, it gets hard to keep track of all active automation
tasks. That’s where [kiwi](http://techprimate.com/kiwi) starts to shine, as its main purpose is combining all relevant
build status reports from all the different providers into a single app.

## Great… now I know what ‘kiwi’ is, but the title said Push Notifications! 🤨

Exactly, so let's get to it.

In the last week, I looked at the possibility of receiving real-time notifications from [Bitrise](http://bitrise.io).
Unfortunately, they do not offer any kind of push notification subscription service (which wouldn’t make sense anyway,
because ‘kiwi’ is not a Bitrise app).

Probably something like a background process that polls for updates solves the issue too, but unfortunately, we can’t
rely on iOS background app refreshes, as mentioned in the
[Apple Documentation](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/updating_your_app_with_background_app_refresh):

> […] If you take too long to update your app, the system may schedule your app less frequently in the future to save
> power. — Apple

Alright, so Bitrise doesn’t support Push Notifications out of the box, and polling is not a solution…

… luckily they support outgoing webhooks 🎉

This means: a user can add a webhook URL to their Bitrise project, and every time a build starts/finishes, an HTTP POST
with an information payload is sent to the URL 🥳

Awesome. Now all that is left to do is redirecting that HTTP POST to push notifications. Easy! Right?

Well unfortunately there is more to it.

In the initial brainstorming purpose I took a look at some common automation providers, such as Zapier, but stopped at
the realization that:

1. it would cost me more to operate than I can earn from it (and I already have paid server capacity available right
   now)
2. it might not be flexible enough for the use case of kiwi
3. Account management would be a hassle, with multiple devices per user, etc.

Instead, I decided to use my own Node.JS API server template (based on Express.js), which I build a while ago (let me
know on Twitter if you want me to release it), and implement my solution. In any way, it is still only a redirection of
the HTTP POST to my kiwi-server, to notify the Apple Push Service.

## Interesting… but how does any of this work?

To send Push Notifications to an iOS device, you need to do the following:

1. Using the Apple Developer account, create an Apple Push Service (APS) token, which needs to be kept **super-secret**,
   as it allows to send notifications to any apps of the developer account!
2. Add the Push Notification Capability to the app
3. Register a device inside the app with the APS, which will return the device identifier (APS Id)
4. Send an HTTP POST request to the APS, using the secret token and the device identifier.

At this point, I won’t go any deeper in how to exactly set up & communicate with the APS, but I would like to recommend
[this raywenderlich.com article](https://www.raywenderlich.com/11395893-push-notifications-tutorial-getting-started),
which helped me with the app setup, and
[this documentation](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/APNSOverview.html)
about APS.

After some tinkering with [\*node-apn](https://github.com/node-apn/node-apn)\* I rather quickly got to the point where
sending notifications to my iPhone worked, but it was still a hard-coded device identifier I manually got from the debug
console in Xcode.

## Mapping webhooks URLs to device APS ids

Now it is time to get more technical, please bear with me (in case something gets unclear, send me a DM on
[Twitter](https://twitter.com/philprimes)).

During brainstorming it became clear that a mapping between secret webhook URLs and device ids would be essential for
notifying the correct devices. Furthermore, it should be possible to subscribe to notifications on a per-project-basis,
and finally, a Bitrise project might be accessed by multiple users, which might use multiple devices… phew!

A few mugs of coffee later, I came up with the following sign-up process:

![Sign Up Process](/assets/blog/ios-push-notifications-without-user-auth/image-2.png)

When a user enables app notifications, the following happens:

1. the iOS device registers with the Apple Push Service (APS)
2. eventually the APS will send a device identifier (_APSId_) to the app
3. the _APSId_ is used to create an account at the kiwi server
4. kiwi server returns an _access token_ which is now used to authenticate
5. the app registers the Bitrise project with its project id/app slug (_BitId_)
6. the app receives a secret webhook URL where status updates are sent to
7. the app adds the webhook URL to the Bitrise project as an outgoing
8. the app subscribes to the project id (_BitId_)

Quite a lot of steps, one would say 😅 But in the ideal case, the user only needs to accept the iOS “Allow kiwi to send
you notifications” alert, and everything else is done in the background automatically

Additionally, the webhook registration (1.5/1.6) might not be necessary anyway, because it has been done before (only
needs to be done once per project), and also some sort of user credentials syncing between multiple devices removes the
signup step itself (1.3/1.4), but would instead need an API for adding more devices.

## “Here… let me tell you what is going on!”

Finally, we have a setup for receiving build status updates and to notify devices, but how does the notification process
itself work?

![Webhook based build status to notification update process](/assets/blog/ios-push-notifications-without-user-auth/image-3.png)

_Webhook based build status to notification update process_

When registering a Bitrise project at the kiwi Server (1.5 in the previous section) a webhook URL is returned, e.g.
**https://api.kiwi.techprimate.com/bitrise/webhooks/*webhookId***

This URL is saved as an outgoing webhook URL into the Bitrise project, and whenever a build starts or finishes (2.1), an
HTTP Post with a JSON payload is sent to the kiwi (2.2):

![Example notification payload from Bitrise](/assets/blog/ios-push-notifications-without-user-auth/image-4.png)

Before further processing, the included _app_slug_ needs to be validated with the one in the database (2.3). If they do
not match, it might be possible that a user reused a webhook URL for multiple projects, which can lead to issues further
down the road (this is not mandatory, but seems good practice).

Looking up the subscriptions in our database leads to a list of devices that need to be notified by sending a
notification to the APS (2.4), which is then responsible for delivering the message to the iOS device.

![Example of kiwi push notification](/assets/blog/ios-push-notifications-without-user-auth/image-5.jpeg)

## More improvements to come!

This solution is not perfect yet, as it comes with some pitfalls:

- the Sign-Up endpoint uses an API Key to block basic bots, but this authorization mechanism is almost useless (everyone
  can extract it from the app, or grab it using a proxy). As the user should not have to deal with any account
  management of kiwi, this stays a known issue. Instead, I will research solutions to validate the APS identifier given
  at the sign-up, therefore relying on the APS for validating sign-ups or blocking malicious accounts later on.
- The access token is used to authenticate the user, therefore it needs to be shared between devices. Some relevant
  options are either export/import to a credentials file, that is synchronized by the users themself, or by using the
  more sophisticated iCloud Keychain.
- Unsubscribing and subscribing to different projects using the authentication token.
- Unit & Integration Testing so the application itself becomes more stable and actually production ready.

Thank you so much for reading! If you would like to know more, follow me on [Twitter](https://twitter.com/philprimes)
and send me a DM with “Ding! New Push Notification is here!”

Also, follow [@KiwiStatusApp](http://twitter.com/KiwiStatusApp) for _kiwi_ app updates and giveaways! 😄
