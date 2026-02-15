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

Welcome to the Series section! 📚

Here you'll find multi-part blog post series that dive deep into technical topics. These series are designed to provide comprehensive coverage of complex subjects, broken down into digestible parts.

### List of Series

{% assign series_posts = site.posts | where_exp: "post", "post.series != nil" | group_by: "series" %}
{% for series_group in series_posts %}
  {% if series_group.name != "" and series_group.name != nil %}
    {% assign sorted_posts = series_group.items | sort: "series_part" %}
    {% assign first_post = sorted_posts.first %}

- [{{ first_post.series_title }}]({{ first_post.url | relative_url }})
  {% endif %}
{% endfor %}
