---
layout: page.liquid
title: Guides
permalink: /guides/
is_top_level: true
description:
  "Comprehensive technical guides and tutorials covering Kubernetes, iOS development, DevOps, and software engineering.
  Step-by-step tutorials for practical learning."
excerpt:
  "Free comprehensive technical guides covering Kubernetes cluster setup, iOS/Swift development, DevOps practices, and
  software engineering. Structured tutorials for hands-on learning."
keywords:
  "technical guides, Kubernetes tutorial, iOS development guide, DevOps tutorial, software engineering, step-by-step
  tutorial, free online course"
image: /assets/images/guides-overview.png
---

Welcome to my guides section! 👋

In addition to my usual blog posts, here you'll find detailed, step-by-step tutorials that are structured like free
online courses. Each guide is written to be comprehensive and practical, walking you through real-world scenarios and
implementations.

These guides are designed to help you learn complex technical topics in a structured way, with clear explanations and
hands-on examples. Whether you're a beginner looking to understand fundamental concepts or an experienced practitioner
wanting to dive deep into specific technologies, these guides aim to provide valuable insights and practical knowledge.

I regularly update and add new guides based on my experiences and learnings in software engineering, DevOps, and cloud
technologies. Each guide is carefully crafted to ensure you can follow along at your own pace while building practical
skills.

If you have ideas for guides or want to know more about a specific topic, feel free to reach out to me!

### List of Guides

{% for page in site.pages %} {% if page.guide_component == 'guide' %}

- [{{ page.title }}]({{ page.url }}) {% endif %} {% endfor %}
