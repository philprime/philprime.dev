---
layout: post
title: "Upgrading Swift HTTP APIs to the Next Level using Postie"
date: 2021-07-05 17:00:00 +0200
categories: blog
---

Defining HTTP APIs in Swift is still not perfect (yet?). Most iOS and macOS apps are using them to communicate with remote data endpoints. And it used to be a hassle with writing and validating requests, sending them, parsing responses, depending on different edge cases etc… and you might think that nowadays, many frameworks exist to solve this complexity…

…but with [Postie](https://github.com/kula-app/Postie/) you can elevate your capabilities even more!

![The Next-Level Swift HTTP API Package](https://cdn-images-1.medium.com/max/2246/1*RVRtUduVLVgrpaIFQVtffw.jpeg)_The Next-Level Swift HTTP API Package_

### Existing solutions are heavy-weight

So what’s the problem with our current state-of-the-art?

The most popular Swift networking framework available, with its **36.000+** stars on GitHub, is [Alamofire](https://github.com/Alamofire/Alamofire). It has a long history of improvements, refactorings and extensions since its [initial release in 2014](https://github.com/Alamofire/Alamofire/releases/tag/1.0.0).

Unfortunately such a long history eventually leads to a bloated code, and you might not need all of the features included in a framework.
A few years ago, I was happy to have a library which helps working with URLSession and took away the JSON parsing, all long before the release of JSONDecoder.
Today we don’t need that anymore, as it became quite simple to work with responses using the built-in features.

### OpenAPI Definition

To begin explaining the core concepts of Postie, let us refresh our knowledge about API definitions.

Originally called the Swagger API definition, the [OpenAPI Specification](https://swagger.io/specification/) is today’s common standard for API definitions. Just look at this snippet from the [Petstore Example](https://editor.swagger.io/), including an endpoint to place an order:

<iframe src="https://medium.com/media/e91c3864abd67d5f8d41601d712ff535" frameborder=0></iframe>

1. the defined host is used as the domain in the URL where we need to send the HTTP request to

1. the basePath is a path prefix which is quite common for API versioning, as it allows to have multiple APIs on the same host

1. inside the paths we define our resource paths. The /store/order is a static one, but the /pet/{petId} requires to set a path parameter petId, which needs to be replaced with some identifier.

1. The /store/order endpoint requires a parameter in the body which needs to be an object with the schema Order. It is declared in the section definitions.

1. The /store/order returns a status code of 200 with another Order object in the response body, or if it the validation fails with the status code 400 and instead an Error object in the body.

1. The Order object contains multiple fields of different types, including int64, int32, date-time strings or even string enums.

As you can see, the request and the response are very well defined. Unfortunately this endpoint brings a few caveats with it, as there are edge cases we need to cover during implementation:

1. The response body schema differs depending on the status code

1. The request body parameter is required and should not be missing.

1. The request URL might require parameters (such as the petId), which might even need to be a specific type (e.g. UUID).
   > Another topic, which I am not covering in this post, is authentication. Many different authentication mechanisms exists, including HTTP Basic (Username + Password), API Keys and OAuth tokens. All of these need to be handled differently and therefore it is too much for this introduction.

Now you know what challenges we are facing. So how can we leverage the power of Swift to help us define well-structured API code?

## Introducing Postie

[Postie](https://github.com/philprime/Postie) is our new Swift package, which takes care of converting our API request types into URLRequest objects, sends them to the endpoint, receives the URLResponse and converts it back into our defined API response types.

The Swift compiler and its strong typing paradigm allows us to take care of all the data structure management.
From a high-level perspective, the main concept uses the already built-in option of creating custom Encoder and Decoder, in combination with Swift 5.1's property wrappers.

Sounds complicated, but fortunately for you, you don’t have to worry about how the magic of Postie works, instead you just have to define your API 🎉

As usual, an example is easier to understand, so let’s start off with a simple HTTP request for our /store/order endpoint:

<iframe src="https://medium.com/media/970601156e0b805cc79f21bb75bee439" frameborder=0></iframe>

We can see that this request includes an HTTP Method, the URL path, a Host header with the remote domain, a Content-Type header declaring the type of data we are sending, and the actual JSON data in the body. Furthermore we also define an Accept header, which tells the remote endpoint what kind of data we would like to receive (also JSON).

So how can this request be declared using Postie?

### Defining an API request

We start off with the simplest approach and add more information further down the road.

Create the following request:

<iframe src="https://medium.com/media/678cc2eed532c95b3130143cbf453edf" frameborder=0></iframe>

Now we change the default HTTP method GET to the POST using the @RequestHTTPMethod property wrapper.

<iframe src="https://medium.com/media/c382dc7c1fc2a4c8151d37bf29b0cf57" frameborder=0></iframe>

Next we need to define the resource path using the @RequestPath property wrapper.

<iframe src="https://medium.com/media/cecc212ae72df1cea159de281a4c7fac" frameborder=0></iframe>

**Note: **As explained earlier, we are *not *adding the prefix v2 to the request path, as the request type itself is not associated with the actual remote host. Instead we have to define the host URL and the prefix with our HTTP client:

<iframe src="https://medium.com/media/5cacd05456dd16ac02e1242ae7577de8" frameborder=0></iframe>

Next, we need to add the request body. From the HTTP request we know that

1. the object is defined as an Order structure

1. it needs to be a JSON object

To tackle 2nd requirement, change the type of CreateStoreOrder from Request to JSONRequest. This will indicate the encoding logic of Postie, that the request body should be converted to JSONdata, and the header Content-Type: application/json needs to be set.

This is also a great example of how the Swift compiler supports us. Immediately after changing the request type, it requires us to adapt the request to add a property body.

![](https://cdn-images-1.medium.com/max/3248/1*raBKjGIaIN_m2UOGv7FzVg.png)

Declare a structure Body which must implement the Encodable pattern and you are all set.

<iframe src="https://medium.com/media/cb461158f4f8b8b09897457e56668b2d" frameborder=0></iframe>

Now we could adapt the Body to have the same structure as our Order schema, but instead we define a Definitions structure so we can reuse it.

<iframe src="https://medium.com/media/f15a0ca8d6203d8190a59915f098ec3e" frameborder=0></iframe>

Great! We are done with declaring our request type 🎉

### Defining the API response

It’s time to define our response type as well, so take a look at the expected HTTP response:

<iframe src="https://medium.com/media/da9bf4ec2fb61adefa9f9f1295ffadc8" frameborder=0></iframe>

Mainly it contains a response status code, response headers and the body data.

To access any information from the response, the associated type Response needs to become an actual struct. We used EmptyResponse earlier, which is a convenience type-alias for following:

<iframe src="https://medium.com/media/36b559ff532b987e5fbea77a3ca2a26d" frameborder=0></iframe>

As a first step, we want to read the response status code. Add a property using the wrapper @ResponseStatusCode.

> **Note:\*** You can name the properties as you wish. If not required by the protocols (e.g. body) only the property wrapper is relevant.\*

<iframe src="https://medium.com/media/07c0537a7811f3bebafd96876338aae0" frameborder=0></iframe>

When decoding the response, Postie will now find the statusCode property and see that it should be set with the actual HTTP response code.

Before defining the response body, let us quickly recap the OpenAPI definition:

<iframe src="https://medium.com/media/8703fc66fad905608eab75c4e1ab9c04" frameborder=0></iframe>

Looks like we need to define **two** responses, which differ depending on the response code. This is also built-in in Postie, as you can not only define a @ResponseBody, but also a @ResponseErrorBody property, which only gets populated when the status code is between 400 and 499.

<iframe src="https://medium.com/media/b425cea77febdd6d39295aa67976e60e" frameborder=0></iframe>

To make this code snippet work, we need to change the Defintions.Order type to not only implement the Encodable protocol, but also the Decodable protocol. Furthermore we need to define the Definitions.Error which should be rather clear at this point.

<iframe src="https://medium.com/media/ea430dbea248cf9d1877d43a1b6afec2" frameborder=0></iframe>

In the final step, we once again need to indicate the decoding logic of Postie, to expect a JSON request body, which is done by changing the Decodable protocol of the type Order to be a JSONDecodable instead (same for Error).

<iframe src="https://medium.com/media/563206a6d0439e6656a78b0f985500a6" frameborder=0></iframe>

Good job! Let’s give ourselves a pat on the back, our API definition is ready💪🏼

### Sending the Request

Using the request definition is easy. All you have to do is create an object CreateStoreOrder and send it using the HTTPAPIClient we declared earlier.

> **Note: **Postie uses the asynchronous event framework [Combine](https://developer.apple.com/documentation/combine) for it’s communication. As it uses the underlying URLSession other async patterns are (if requested) possible too.

<iframe src="https://medium.com/media/3ee3e16d0b8ae4e22afc47c97aff8221" frameborder=0></iframe>

As our CreateStoreOrder has an associated Response type, we won’t have to define the expected response type again or worry about its parsing logic.

From now on we simply **use **our API.

## Many more features

There are many more features available, but I couldn’t cover them all in this story. It’s highly recommend that you checkout the vast [README guide](https://github.com/kula-app/Postie/) to see the full feature-set.

Just to give you a glance of what else is available:

- @RequestHeader defines request headers

- @ReponseHeader to read a specific header from the response

- @QueryItem to add typed fields to the request URL query

- @RequestPathParameter to set typed parameters in the URL (such as the petId from our example)

…and more!

## So, what’s different?

You might be wondering why we consider Postie being different to other frameworks/packages.

I mentioned earlier that other frameworks are heavy-weight and include many features, which stay unused for most of the users. As Postie will eventually grow with its feature set too, our counter-measurements are keeping the core slim, probably implement a multi-package approach, and require as little information as possible, when defining the API.

Our approach using property wrappers enables just that. Other frameworks require to either pass the additional headers or values as function parameters when sending the request, but Postie stays true to an object-oriented approach:

> A request is a single data object which contains all relevant information to receive the expected response.

## Road-Map

Postie will eventually evolve into a fully-fledged HTTP framework, taking care of all the data conversion and requirements validation. The main goal is having an object-oriented Request-Response pattern, which allows a developer to worry less about _how_ the API should be used, but instead _what_ to do with it.

At the time of writing, Postie supports JSON and Form-URL-Encoded data, but we are also planning to support XML in the future.

With the rise of async-await in Swift 5.5 the current Combine-based sending logic will be extended. If requested, we will also include legacy-style callbacks.

Additional ideas include a [Swiftgen](https://github.com/SwiftGen/SwiftGen) template to automatically transform the OpenAPI specification directly into ready-to-use Postie request definitions.

Even tough the package is still under active development, we are going to use it for production apps at [techprimate](https://www.techprimate.com/) and validate the usage, eventually bumping it to version 1.0.0

## Conclusion & Contribution

Follow the [repository](https://github.com/kula-app/Postie/) and submit your feature requests. It started as an Open Source project and should remain one, so we all can profit from each other. Found a bug? [Let us know!](https://github.com/kula-app/Postie/issues/new)

I also would love to hear what you think about this project. Follow me on [Twitter](https://twitter.com/philprimes) and feel free to drop a DM with your thoughts.
Also checkout [my other articles](philpri.me/blog). You have a specific topic you want me to cover? Let me know! 😃
