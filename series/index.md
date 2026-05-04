---
layout: page.liquid
title: Series
permalink: /series/
is_top_level: true
description: "Browse blog post series covering in-depth technical topics. Multi-part articles diving deep into Swift API design, iOS development, and software engineering."
excerpt: "Explore comprehensive blog post series covering technical topics in depth. Multi-part articles on Swift API design, iOS development, and more."
keywords: "blog series, technical series, multi-part articles, Swift series, iOS development series"
image: /assets/images/default-og-image.png
---

Some topics are too big for a single post.
Each series here dives deep into a technical subject, broken down into focused parts that build on each other.

You can start with Part I and work your way through at your own pace.
I will keep adding new series as I explore topics worth covering in depth.

{% assign series_posts = site.posts | where_exp: "post", "post.series != nil" | group_by: "series" %}

<div class='card-grid'>
{% for series_group in series_posts %}
{% if series_group.name != "" and series_group.name != nil %}
{% assign sorted_posts = series_group.items | sort: "series_part" %}
{% assign first_post = sorted_posts.first %}
<a class='card' href='{{ first_post.url | relative_url }}'>
  {% if first_post.image %}
  <img src='{{ first_post.image | relative_url }}' alt='{{ first_post.series_title | escape }}' loading='lazy' />
  {% endif %}
  <div class='card-content'>
    <h3>{{ first_post.series_title | escape }}</h3>
    <p class='card-meta'>{{ sorted_posts.size }} parts</p>
    {% if first_post.description %}
    <p class='card-description'>{{ first_post.description | truncatewords: 25 }}</p>
    {% endif %}
  </div>
</a>
{% endif %}
{% endfor %}
</div>
