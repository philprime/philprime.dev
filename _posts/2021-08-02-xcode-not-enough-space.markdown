---
layout: post
title: 'Installing Xcode with "not enough disk space available"'
date: 2021-08-02 15:59:40 +0200
categories: blog
---

# Installing Xcode with “not enough disk space available"

Phrases like “Xcode Beta 1X.Y.Z is out now" or “Did you try the new features of the latest Xcode update yet?" fill an iOS/macOS developer with joy. A new IDE update can be something similar to, e.g. a new knife for a chef, or a kid receiving the toy it always wanted.

But then, the devastating moment, destroying all happiness at once:

> # “Xcode.xip can’t be expanded because the current volume doesn’t have enough free space."

![Error prompt](/assets/blog/xcode-not-enough-space/xcodes-error-prompt.png)_Error prompt from the **Xcodes App** ([github.com/RobotsAndPencils/XcodesApp](https://github.com/RobotsAndPencils/XcodesApp))_

The initial reaction: “Huh. Wait a minute? I do have enough space, don’t I?".
Then you check your disk usage statistics, and yes, looks like there should be enough free space.

So what is the problem and how can we solve it? Let’s narrow it down.

## TL;DR (Too Long; Didn’t Read)

Here’s the solution to installing Xcode when you get this error:

Create a very large file (multiple GBs) using dd (or similar), wait a moment, then delete it (and clear your Trash).
Now you have enough free space to install Xcode.

```bash
dd if=/dev/urandom of=temp_20GB_file bs=1024 count=$[1024*1024*20]
```

Still interested in the full reason why this is working? Keep reading.

## What is the Problem? Is it really the disk size?

We start wondering: “so how much space would I need now?". If you checkout the Mac App Store entry for Xcode, it states **11.7 GB** size. But, even if we have more available, it fails with the same error.

Unfortunately the download process of the App Store is quite obscure, and therefore not a great starting point to investigate the issue.

Instead we can directly download a compressed version of Xcode from the developer resources on [developer.apple.com](https://developer.apple.com). When downloading the Xcode app, we are actually downloading an xip archive.
To cite the man xip documentation: “The xip tool is used to create a digitally signed archive". This is used in macOS to prove the authenticity of an archive.

Great, downloading worked out fine, I got the archive on my MacBook, so let’s look at it:

![](/assets/blog//xcode-not-enough-space/xcode-xip-size.png)

The archive has about 11 GB of file size. That is quite a lot of data, especially for an archive which is the _compressed_ version of `Xcode.app`.
So how much space do we really need for the full app, on our disk?

![Expanded Xcode Size](/assets/blog/xcode-not-enough-space/xcode-xip-size-expanded.png)_To be honest, I have no idea how 29.51 GB are 16.68 GB on disk_

We need a whopping **30 GB** of space on our disk. This is a challenge, especially for developers with small drives. Fortunately for me, when I got my MacBook Pro in 2017, I opted-in for a 512 GB version, so in this case there **should** be enough space left to fit a 30 GB app for sure.

Clicking on the Apple Symbol in the top-left corner and further clicking the “_About This Mac_" menu option, opens up the storage information.

Well, look at it: **39.54 GB** of space is available.

![Multiple volumes allow me to easily reinstall macOS without loosing much data.](https://cdn-images-1.medium.com/max/2792/1*akjiCM0Zt08pA2AfwgOpZQ.png)_Multiple volumes allow me to easily reinstall macOS without loosing much data._

Wait… so what is going on? Why is the install process dying with a “not enough space available"-warning even tough there should be at least `39.5 GB — 29,5 GB =` **10 GB** **more available than necessary**?

While inspecting this behavior, I found an interesting side-effect of the xip unarchiver: It checks for enough disk space _before_ actually writing any data.

After tinkering with solutions and researching on the internet, I came up with a theory.

## The Real Problem: APFS Containers

> **_Disclaimer_**: This has not been verified by enough research (as my time is limited and solution-oriented) and I would love to hear your feedback either confirming or denying these assumptions, preferably per [DM on Twitter](https://twitter.com/philprimes).

In 2017 Apple introduced us the successor of the HFS+ file system, the "Apple File System" (APFS). A file system is the low-level technology which defines, how the data is stored on hardware, and how it can be read from it. It brings many great features with it, such as encryption, super-fast file duplication and increased data integrity.

Another great feature of APFS are Containers. To give you full context of what containers are, and why they are so awesome, I will give you a short summary on storage technologies (as far as I remember from my university lectures 😄).

### Concepts of File Systems

A storage disk is split into _blocks_, each one consisting of multiple bytes of data. On Unix, each block has [a size of 4KB](https://web.cs.wpi.edu/~rek/DCS/D04/UnixFileSystems.html). As an example: if we have a disk with 128 blocks with 4KB each, that means we have a total disk size of 512 KB.

As multiple file systems with different features (e.g. case-sensitive file names) exist, we eventually want to install multiple ones on the same disk. This requires us to split our disk space into multiple _partitions._

A partition is a range of assigned blocks, e.g. partition A has block 0–63 and partition B is 64-127 assigned, and each partition is formatted with a specific file system (e.g. APFS, HFS+, NTFS, exFAT etc.).

The partition system is still widely used today, but it has a major drawback on usability: If we run out of space on partition A, the only way to use the free space of partition B is resizing (= reassigning blocks) of the latter one to the first one.
Even worse, sometimes the blocks must be sequential, and so we can’t resize the partitions without shifting all data inside the blocks, by reading and writing them to a different position.

> I had to do this once to fix a BootCamp installation and even tough I feel comfortable with low-level computing, it was a hurdle to deal with the partition table. Hopefully I’ll never have to do that again.

Luckily we got APFS containers now 🎉 These containers are built on top of partitions, with the great advantage of having a dynamic size.

**Example:** At first our 128 blocks are assigned to a single APFS partition. Then we create two containers A and B. Their current size is defined by the APFS controller software, and while writing large data, they grow as needed.
When you delete files, it takes some time, but eventually the container shrinks down, so that the cleared space is available once again.
Now the free space could also be used to grow the container B.

Sounds great, doesn’t it? Well yes, but on the other hand it is quite ironic that this dynamic “advantage" is actually the root of our problems, while installing Xcode.

As you can see in the screenshot earlier, about 40 GB of space is available, but if you open up the Disk Utility.app shipped with macOS, it states something different:

![Disk Utility is a macOS application to inspect and format storage devices.](/assets/blog/xcode-not-enough-space/disk-utility.png)_Disk Utility is a macOS application to inspect and format storage devices._

Even tough the storage information from “_About This Mac_" showed me the _real_ 40 GB of available space, the container currently only has **~22GB** of space assigned to it! This is not unexpected, because the container would grow _while writing data_ and could therefore eventually use up the full 40 GB.

But it seems as the xip disk-space-check looks at the free space _inside the container_ before writing, and not the _fully available disk space_, and therefore _no writing is happening._

We found the contradiction causing our issue:

> # APFS containers grow while writing data, but the unarchiver won’t start writing data, because the container didn’t grow enough (yet).

## The Solution: Manually Scaling the Container

To solve the contradiction, we have to force the container to grow. The only viable solution to do so, is writing a huge amount of data.

Unfortunately due to the nature of APFS we probably can’t simply duplicate large files on our computer (as this was one of the marketing features of the WWDC Keynote).

Now, we could download large test files, such as [the ones from Hetzer.de](https://speed.hetzner.de/).
But it isn’t reasonable to create this large network traffic, if we simple need random, local bytes. Also it would take forever with low network bandwidth.

The easiest solution is using your favorite search engine to lookup “create large file macOS" and finding posts [like this one](https://www.cyberciti.biz/faq/howto-create-lage-files-with-dd-command/) or [this one on StackOverflow](https://stackoverflow.com/a/26796777/3515302).

The core of macOS is Unix, which offers a built-in random data stream file at /dev/urandom. To create a large file filled with random data, run the following command in your terminal of choice:

```bash
dd if=/dev/urandom of=temp_20GB_file bs=1024 count=$[1024*1024*20]
```

It will read the random data and write it to a file temp_10GB_file, which will indicate our APFS container to grow. After writing the data, we can delete the generated file and for a little while the container will be large enough for the xip-unarchiver-disk-space-check™ to pass.

Now you should have enough disk space to finish installing Xcode 🥳

## Conclusion:

This is an interesting behavior of macOS and the Apple File System, which might not be intended by their developers. I will go ahead and create a bug report to let them know about these findings. Maybe they can create a sustainable solution for us all.

I hope you enjoyed this story and hopefully it helped to fix your issue too. The idea for this article actually sparked by a post on Twitter, so if you want to read more content like this, make sure to follow me there 😁

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">If you have issues installing Xcode due to &quot;not enough space&quot; (8.22 GB) even tough you have enough (35.4 GB), check Disk Utility. <br>You might have to reclaim the APFS container space by creating a 20GB file and delete it afterwards <a href="https://t.co/AaegfiRrEE">pic.twitter.com/AaegfiRrEE</a></p>&mdash; Philip (Phil) Niedertscheider (@philprimes) <a href="https://twitter.com/philprimes/status/1417085891458252801?ref_src=twsrc%5Etfw">July 19, 2021</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

You have a specific topic you want me to cover? Let me know! 😃
