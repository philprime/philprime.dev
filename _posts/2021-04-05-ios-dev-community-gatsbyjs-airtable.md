---
layout: post.liquid
title: 'Mobile App Developer Community built with GatsbyJS & Airtable'
date: 2021-04-05 17:00:00 +0200
categories: blog
tags: web GatsbyJS Airtable React community Vienna mobile-development static-site-generator
description:
  'Learn how to build a mobile app developer community website using GatsbyJS and Airtable. This tutorial covers
  creating a static site generator with dynamic data sources and no-code database solutions.'
excerpt:
  'Discover how I built Vienna-app.dev, a mobile developer community platform using GatsbyJS and Airtable. Learn about
  combining static site generation with no-code databases for rapid development.'
keywords:
  'GatsbyJS, Airtable, mobile app community, static site generator, React, no-code database, web development, developer
  community'
image: /assets/blog/ios-dev-community-gatsbyjs-airtable/image-2.png
author: Philip Niedertscheider
---

Vienna is a beautiful city with high living standards and a modern mindset. It’s time to not only enjoy its diversity
but to actively explore the potential of becoming the next great startup city.

The following story will start off less technical, and instead more historical/personal. Skip to _“My first time with
GatsbyJS”_ if you only want to hear about the implementation 😊

![Combining GatsbyJS & Airtable makes it easy to build a web app](/assets/blog/ios-dev-community-gatsbyjs-airtable/image-1.jpeg)

_Combining GatsbyJS & Airtable makes it easy to build a web app_

Almost 4 years ago, in 2017, I moved from a small city to Austria’s Capitol, Vienna, to study Software Engineering at
Vienna University of Technology (TU Wien). As I have mostly been self-taught in the 4 years before, I finally wanted to
learn it by the book. Next to studying I started to manifest my know-how on iOS mobile app development, eventually
founding my own mobile app development agency _techprimate_ in 2018.

Another three years passed, and I am still living in Vienna, still studying, still building software as my passion.
After some failed projects in 2019 and struggling with university at that time, pivoting my goals became necessary. In
2020 I decided to invest more time into becoming known in the developer community, to have a larger network where I can
share my knowledge and learn from others. The first step was doing a summer internship as a back-end developer at
f[usonic](https://www.fusonic.net/en/), and afterward starting as a part-time iOS/macOS developer at
[WolfVision](https://wolfvision.com/en). During that time I was able to meet great new developers, learn how others
work, and apply my capabilities.

One day, after listening to a great talk of [Max Stoiber](https://twitter.com/mxstbr) “How Open Source changed (his)
life”, one major thought kept stuck in my head:

> Share with others, what you are currently working on. There is no value in keeping everything to yourself, especially
> if you never get to release it to the world… build it in public!

This isn’t quite a quote of Max (as I just made these words up in my head while writing this article 😄), but basically
what I got from his talk is, that all the side-projects on my computer or in my private git repositories are just
decaying, as everything around keeps evolving.

Well… I have already been a part of the Open Source community, when I started
[TPPF](https://github.com/techprimate/TPPDF), a Swift PDF Generator framework, in 2016, and even though I am personally
not using it anymore, the community using it keeps growing every day. This is enough reason for me to keep maintaining
it (as much as possible). Because of its success and me actively relying on Open Source too in many aspects, I became a
strong Open Source advocate!

As an (unfortunate) example, I also experienced where being too secretive can lead to: In the past, we built a school
app at techprimate. As we feared competition we kept it as secret as possible, which lead to the project failing…
because we didn’t have enough feedback, when it became inevitably necessary.

All this led to a new strategy for 2021:

> Sharing my content with others & building projects in the public, will help others and lead to feedback eventually!

This is my motivation to write blog posts, like the one you are reading right now! 😄

## Why another app portfolio website?

An awesome monthly online event called “[iOS Dev Happy Hour](https://www.iosdevhappyhour.com/)” was launched about 7
months ago on Twitter (by [Allen W](https://twitter.com/codeine_coding)) and last month I finally got the chance to
participate. It showed me once again how diverse and fascinating the international iOS Developer Community is, how
important a great network can be, and how interesting the projects of other developers are.

During some research on local events in Vienna afterward, a new idea hit me: A website, where mobile app developers
(such as myself) can find other apps, and furthermore their developers, in the same area. This has a lot of potential,
as eventually we can use the platform to gather information about other events/projects/etc. which are going on in
Vienna, and eventually become an important resource in the Viennese mobile developer & startup community.

The concept is quite simple:

- mobile app developers working or living in Vienna can submit their apps with some basic metadata and a web link to the
  website.
- Afterward, we at techprimate review the submissions and add the app to the portfolio 🚀
- Finally, others can find the app there, and the submitted weblink leads a visitor to the developer (company/team).

We want to build a community! And luckily we had the perfect domain available: [vienna-app.dev](http://vienna-app.dev)

![](/assets/blog/ios-dev-community-gatsbyjs-airtable/image-2.png)

## Start small, but with high quality!

The idea was born. And as my co-founder Jules liked the idea too, we did some brainstorming on how to implement it on a
UX and technical level.

In the previous years, next to building apps, I also got into back-end development — starting with my very first little
[Node.js](https://nodejs.org/en/) [express](https://expressjs.com/) server hosted on [Heroku](https://www.heroku.com/)
(I had no idea how else), to learning how to use [Docker](https://www.docker.com/) to isolate projects into containers,
to becoming an (early) adopter of the [serverless Framework](https://www.serverless.com/), and eventually up to using
[AWS](https://aws.amazon.com/) services to built highly distributed services.

In the end, the power of understanding many technologies leads to a software developer's downfall… we over-engineer
simple solutions.

As another (personal) example, our domain _[techprimate.com](http://techprimate.com)_ went through different stages of
complexity too:

- the very first website was originally a [Wordpress](https://wordpress.com/) blog in 2014 🤯
- afterward, the first “app-team” website with a custom design was built in 2015 (long before founding the company) by
  myself, and was written in PHP based on [Symfony](https://symfony.com/) 👨‍🎨
- in 2016 I rebuilt the same website but using [Laravel](https://laravel.com/) with an admin area (I believe it was the
  [Gentelella](https://github.com/ColorlibHQ/gentelella) template) 👨‍💻
- in 2018 after founding the company, we hired our study colleague (and now roommate) René and he built a static HTML
  website from scratch (once again custom design by us) using only [Sass](https://sass-lang.com/) for stylesheet
  compilation 🎓
- in 2020 we were still unsatisfied with what we got: no team information, hardly any of our projects showcased, not as
  easy to improve as we wished, as every change had to be custom designed. We decided to scrap everything to get a fresh
  restart after pivoting to an agency: no fancy build tools, no custom design (we are mobile developers, not web
  designers anyway), no heavy back-end requiring maintenance. Instead, we purchased a static HTML template and focused
  on the content rather than the technology… and it has been a success so far! 🏆

The story doesn’t end here, as now we have so much going on at [techprimate](http://techprimate.com), that manually
editing every single HTML website becomes repetitive. We will look into code generators and maybe even a back-end with
admin area further down the road — but this time our main focus will stay on the content of the website, rather than the
artistic aspect!

As I am a still huge fan of automation (one of the reasons why I am building
[kiwi](https://www.techprimate.com/kiwi.html)) repeating stupid tasks over and over should not be the everyday reality,
so I had to find a balance between the static & the dynamic aspect for building the
[vienna-app.dev](http://vienna-app.dev) community.

## My first time with GatsbyJS 😄

While looking into static page generators for _techprimate.com_ a few candidates popped up, such as
[Jekyll](https://jekyllrb.com/), [Hugo](https://gohugo.io/), [Publish](https://github.com/JohnSundell/Publish), and
more… but in the end, I decided to give [GatsbyJS](https://www.gatsbyjs.com/) a shot for _vienna-app.dev_.

> The hardest parts of the web, made simple. — [gatsbyjs.com](https://www.gatsbyjs.com/)

Gatsby builds a [React](https://reactjs.org/) website and uses server-side rendering to generate a website based on
static source you (might) have only available at the build time. Sounds good so far.

As mentioned before, the community website should allow developers to submit their apps, therefore some kind of backend
service is needed. Luckily Jules is currently researching all kinds of nocode/lowcode solutions for
[another project](https://www.kula.app/) and introduced me to [Airtable](https://twitter.com/copieman), a service I
would describe as an “easy-to-use-database with automation”.

With Airtable it was quite simple to create a table with the necessary fields:

- App Name → name of the app (duh!)
- App Creator → developer or company name
- App Icon → a square icon
- App Description → a small summary describing the app on vienna-app.dev
- Website → a link to promote, can be either a download or product link
- Twitter (optional) → a great place for developers to build a network

Now, this isn’t such a big requirement, I could have easily built this using a Postgres database too, but for me, the
important key feature is the simple form creation. Airtable allows me to offer interested developers to directly submit
their apps into my database. Then I utilize automation scripts to create the dataset necessary for generating the static
HTML website with GatsbyJS. Additionally due to its simple interface I don’t have to do any coding to get it all working
🎉

… well, to be honest, in the end, it wasn’t an entirely no-code-database, as I had to write a small Automation in
JavaScript to merge the original submission with further update requests, but that’s a completely different story to
building a fully-blown API server.

Now I have my site generator and my database and it’s time for some developer magic ✨

Gatsby is based on a plugin structure, where source plugins provide data to the application from different providers
(e.g. from a file or an API) and other plugins to add more features or transform data into our HTML/JS/CSS website.

Luckily the [gatsby-source-airtable](https://www.gatsbyjs.com/plugins/gatsby-source-airtable/) plugin exists 🔥

![gatsby-source-airtable allows to fetch data from Airtable](/assets/blog/ios-dev-community-gatsbyjs-airtable/image-4.jpeg)

The Airtable source plugin fetches the data at the start of the development server and saves it into a temporary file
which can then be queried using the default Gatsby GraphQL data interface.

We purchased a Gatsby template that perfectly fitted our needs: sleek design and perfect for showcasing many apps. Now,
whenever the Airtable data changes, I can re-run the build process locally and deploy the updated website 🚀

## Deploying a GatsbyJS website using Docker

Now when it came to deploying the static website I had a few options:

- Uploading the build folder to one of my servers using (S)FTP.
- Creating a Git repository with build commits, which are automatically pulled onto a web server.
- Uploading to some external static file hosting service, like AWS S3.
- Using GitHub pages for hosting the webpage.
- Creating Docker images and running them in some environment, such as one of my servers.

I decided to go with the latter one, as I have recently created learned how to use Docker Swarm for automatic deployment
updates.

Creating your own docker image is fairly simple, especially when using multi-stage builds (which are also quite new).
First, you create your Dockerfile with one stage building the website, and another stage copying the build products into
a static server (e.g. NGINX).

I won’t go into detail about [multi-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/) (if
you want a full tutorial, let me know on [Twitter](http://twitter.com/philprime)). The final Dockerfile looks like this
one:

![Dockerfile for building multi-stage GatsbyJS website using NGINX](/assets/blog/ios-dev-community-gatsbyjs-airtable/image-3.png)_Dockerfile
for building multi-stage GatsbyJS website using NGINX_

Now I can [build](https://docs.docker.com/engine/reference/commandline/build/),
[tag](https://docs.docker.com/engine/reference/commandline/tag/) and
[push](https://docs.docker.com/engine/reference/commandline/push/) the application and update my servers using
versioning in my Docker Swarm 🥳

If the project gains more traction this process will get more automated or even be extended using a live API at some
point, but as mentioned before: Start small!

## What’s next to come?

This is version v1.0 of vienna-app.dev, therefore it is quite bare and it will take some time to improve and more
developers to submit their apps. Anyways I am very happy with the very quick progress after **a single week** of
development and excited to see where it goes!

If you would like to know more, check out my other posts, follow me on [Twitter](https://twitter.com/philprimes), and
feel free to drop me a DM.

Do you have more ideas to improve this project? Let me know!

You are/know someone living or working in Vienna and building mobile apps?
[Submit your apps!](https://www.vienna-app.dev/submission/create) 😃
