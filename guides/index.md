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

In addition to my usual blog posts, here you will find detailed, step-by-step tutorials structured like free online courses.
Each guide walks you through real-world scenarios with clear explanations and hands-on examples.

Whether you are just getting started with a topic or looking to go deeper, these guides are designed to help you learn at your own pace while building practical skills.
I regularly add new guides based on my experiences in software engineering, DevOps, and cloud technologies.

If you have ideas for a guide or want to know more about a specific topic, feel free to reach out on [X](https://x.com/philprimes), [BlueSky](https://bsky.app/profile/philprime.dev), or [LinkedIn](https://www.linkedin.com/in/philipniedertscheider)!

<div class='card-grid'>
{% for page in site.pages %}
{% if page.guide_component == 'guide' %}
<a class='card' href='{{ page.url | relative_url }}'>
  {% if page.image %}
  <img src='{{ page.image | relative_url }}' alt='{{ page.title | escape }}' loading='lazy' />
  {% endif %}
  <div class='card-content'>
    <h3>{{ page.title | escape }}</h3>
    {% assign lessons = site.pages | where: "guide_component", "lesson" | where: "guide_id", page.guide_id %}
    <p class='card-meta'>{{ lessons.size }} lessons</p>
    {% if page.guide_abstract %}
    <p class='card-description'>{{ page.guide_abstract | truncatewords: 25 }}</p>
    {% endif %}
  </div>
</a>
{% endif %}
{% endfor %}
</div>
