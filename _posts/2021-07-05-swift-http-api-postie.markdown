---
layout: post
title: "Upgrading Swift HTTP APIs to the Next Level using Postie"
date: 2021-07-05 17:00:00 +0200
categories: blog
---

Defining HTTP APIs in Swift is still not perfect (yet?). Most iOS and macOS apps are using them to communicate with remote data endpoints. And it used to be a hassle with writing and validating requests, sending them, parsing responses, depending on different edge cases etc… and you might think that nowadays, many frameworks exist to solve this complexity…

…but with [Postie](https://github.com/kula-app/Postie/) you can elevate your capabilities even more!

![The Next-Level Swift HTTP API Package](/assets/blog/swift-http-api-postie/postie-header.jpg)_The Next-Level Swift HTTP API Package_

### Existing solutions are heavy-weight

So what’s the problem with our current state-of-the-art?

The most popular Swift networking framework available, with its **36.000+** stars on GitHub, is [Alamofire](https://github.com/Alamofire/Alamofire). It has a long history of improvements, refactorings and extensions since its [initial release in 2014](https://github.com/Alamofire/Alamofire/releases/tag/1.0.0).

Unfortunately such a long history eventually leads to a bloated code, and you might not need all of the features included in a framework.
A few years ago, I was happy to have a library which helps working with URLSession and took away the JSON parsing, all long before the release of JSONDecoder.
Today we don’t need that anymore, as it became quite simple to work with responses using the built-in features.

### OpenAPI Definition

To begin explaining the core concepts of Postie, let us refresh our knowledge about API definitions.

Originally called the Swagger API definition, the [OpenAPI Specification](https://swagger.io/specification/) is today’s common standard for API definitions. Just look at this snippet from the [Petstore Example](https://editor.swagger.io/), including an endpoint to place an order:

```yaml
swagger: "2.0"
host: "petstore.swagger.io"
basePath: "/v2"
paths:
  /store/order:
    post:
      summary: "Place an order for a pet"
      parameters:
        - in: "body"
          name: "body"
          description: "order placed for purchasing the pet"
          required: true
          schema:
            $ref: "#/definitions/Order"
    responses:
      "200":
        description: "successful operation"
        schema:
          $ref: "#/definitions/Order"
      "400":
        description: "Invalid Order"
        # this is added for the example
        schema:
          $ref: "#/definitions/Error"
  /pet/{petId}: {} ...
definitions:
  Order:
    type: "object"
    properties:
      id:
        type: "integer"
        format: "int64"
      petId:
        type: "integer"
        format: "int64"
      quantity:
        type: "integer"
        format: "int32"
      shipDate:
        type: "string"
        format: "date-time"
      status:
        type: "string"
        description: "Order Status"
        enum:
          - "placed"
          - "approved"
          - "delivered"
      complete:
        type: "boolean"
        default: false
  Error:
    type: "object"
    properties:
      message:
        type: "string"
        description: "Error message"
```

1. the defined host is used as the domain in the URL where we need to send the HTTP request to
2. the basePath is a path prefix which is quite common for API versioning, as it allows to have multiple APIs on the same host
3. inside the paths we define our resource paths. The /store/order is a static one, but the /pet/{petId} requires to set a path parameter petId, which needs to be replaced with some identifier.
4. The /store/order endpoint requires a parameter in the body which needs to be an object with the schema Order. It is declared in the section definitions.
5. The /store/order returns a status code of 200 with another Order object in the response body, or if it the validation fails with the status code 400 and instead an Error object in the body.
6. The Order object contains multiple fields of different types, including int64, int32, date-time strings or even string enums.

As you can see, the request and the response are very well defined. Unfortunately this endpoint brings a few caveats with it, as there are edge cases we need to cover during implementation:

1. The response body schema differs depending on the status code
2. The request body parameter is required and should not be missing.
3. The request URL might require parameters (such as the petId), which might even need to be a specific type (e.g. UUID).

> Another topic, which I am not covering in this post, is authentication. Many different authentication mechanisms exists, including HTTP Basic (Username + Password), API Keys and OAuth tokens. All of these need to be handled differently and therefore it is too much for this introduction.

Now you know what challenges we are facing. So how can we leverage the power of Swift to help us define well-structured API code?

## Introducing Postie

[Postie](https://github.com/philprime/Postie) is our new Swift package, which takes care of converting our API request types into URLRequest objects, sends them to the endpoint, receives the URLResponse and converts it back into our defined API response types.

The Swift compiler and its strong typing paradigm allows us to take care of all the data structure management.
From a high-level perspective, the main concept uses the already built-in option of creating custom Encoder and Decoder, in combination with Swift 5.1's property wrappers.

Sounds complicated, but fortunately for you, you don’t have to worry about how the magic of Postie works, instead you just have to define your API 🎉

As usual, an example is easier to understand, so let’s start off with a simple HTTP request for our /store/order endpoint:

```http
POST /v2/store/order HTTP/2
Host: petstore.swagger.io
Accept: application/json
Content-Type: application/json
Content-Length: 129

{
  "id": 1,
  "petId": 2,
  "quantity": 3,
  "shipDate": "2021-07-04T08:21:56.169Z",
  "status": "placed",
  "complete": false
}
```

We can see that this request includes an HTTP Method, the URL path, a Host header with the remote domain, a Content-Type header declaring the type of data we are sending, and the actual JSON data in the body. Furthermore we also define an Accept header, which tells the remote endpoint what kind of data we would like to receive (also JSON).

So how can this request be declared using Postie?

### Defining an API request

We start off with the simplest approach and add more information further down the road.

Create the following request:

```swift
import Postie

struct CreateStoreOrder: Request {
   // Ignores the response
   typealias Response = EmptyResponse
}
```

Now we change the default HTTP method GET to the POST using the @RequestHTTPMethod property wrapper.

```swift
struct CreateStoreOrder: Request {

    typealias Response = EmptyResponse

    @RequestHTTPMethod var method = .post

}
```

Next we need to define the resource path using the @RequestPath property wrapper.

```swift
struct CreateStoreOrder: Request {

    typealias Response = EmptyResponse

    @RequestHTTPMethod var method = .post
    @RequestPath var path = "/store/order"

}
```

**Note: **As explained earlier, we are *not *adding the prefix v2 to the request path, as the request type itself is not associated with the actual remote host. Instead we have to define the host URL and the prefix with our HTTP client:

```swift
import Foundation
import Postie

struct CreateStoreOrder: Request {

    typealias Response = EmptyResponse

    @RequestHTTPMethod var method = .post
    @RequestPath var path = "/store/order"

}

let host = URL(string: "https://petstore.swagger.io")!
let basePath = "v2"
let client = HTTPAPIClient(url: host, pathPrefix: basePath)
```

Next, we need to add the request body. From the HTTP request we know that

1. the object is defined as an Order structure
2. it needs to be a JSON object

To tackle 2nd requirement, change the type of CreateStoreOrder from Request to JSONRequest. This will indicate the encoding logic of Postie, that the request body should be converted to JSONdata, and the header Content-Type: application/json needs to be set.

This is also a great example of how the Swift compiler supports us. Immediately after changing the request type, it requires us to adapt the request to add a property body.

![](/assets/blog/swift-http-api-postie/1_raBKjGIaIN_m2UOGv7FzVg.png)

Declare a structure Body which must implement the Encodable pattern and you are all set.

```swift
struct CreateStoreOrder: JSONRequest {

    typealias Response = EmptyResponse

    @RequestHTTPMethod var method = .post
    @RequestPath var path = "/store/order"

    struct Body: Encodable {}
    var body: Body
}
```

Now we could adapt the Body to have the same structure as our Order schema, but instead we define a Definitions structure so we can reuse it.

```swift
enum Definitions {
    struct Order: Encodable {
        enum Status: String, Encodable {
            case placed
            case approved
            case delivered
        }

        let id: Int64
        let petId: Int64
        let quantity: Int32
        let shipDate: String
        let status: Status
        var complete: Bool = false
    }
}

struct CreateStoreOrder: JSONRequest {

    typealias Response = EmptyResponse

    @RequestHTTPMethod var method = .post
    @RequestPath var path = "/store/order"

    var body: Definitions.Order
}
```

Great! We are done with declaring our request type 🎉

### Defining the API response

It’s time to define our response type as well, so take a look at the expected HTTP response:

```http2
HTTP/2 200 OK
date: Sun, 04 Jul 2021 08:43:07 GMT
content-type: application/json
content-length: 212

{
  "complete": false,
  "id": 1,
  "petId": 2,
  "quantity": 3,
  "shipDate": "2021-07-04T08:21:56.169Z",
  "status": "placed"
}
```

Mainly it contains a response status code, response headers and the body data.

To access any information from the response, the associated type Response needs to become an actual struct. We used EmptyResponse earlier, which is a convenience type-alias for following:

```swift
struct CreateStoreOrder: JSONRequest {

    struct Response: Decodable {

    }

    // ...request definition here...
}
```

As a first step, we want to read the response status code. Add a property using the wrapper @ResponseStatusCode.

> **Note:** You can name the properties as you wish. If not required by the protocols (e.g. body) only the property wrapper is relevant.

```swift
struct CreateStoreOrder: JSONRequest {

    struct Response: Decodable {

        @ResponseStatusCode var statusCode

    }
    // ...request definition here...
}
```

When decoding the response, Postie will now find the statusCode property and see that it should be set with the actual HTTP response code.

Before defining the response body, let us quickly recap the OpenAPI definition:

```yaml
responses:
  "200":
    description: "successful operation"
    schema:
      $ref: "#/definitions/Order"
  "400":
    description: "Invalid Order"
    schema:
      $ref: "#/definitions/Error"
```

Looks like we need to define **two** responses, which differ depending on the response code. This is also built-in in Postie, as you can not only define a @ResponseBody, but also a @ResponseErrorBody property, which only gets populated when the status code is between 400 and 499.

```swift
struct Response: Decodable {

   @ResponseStatusCode var statusCode
   @ResponseBody<Definitions.Order> var body
   @ResponseErrorBody<Definitions.Error> var errorBody

}
```

To make this code snippet work, we need to change the Defintions.Order type to not only implement the Encodable protocol, but also the Decodable protocol. Furthermore we need to define the Definitions.Error which should be rather clear at this point.

```swift
enum Definitions {
    struct Order: Encodable, Decodable {
        enum Status: String, Encodable, Decodable {
            case placed
            case approved
            case delivered
        }

        let id: Int64
        let petId: Int64
        let quantity: Int32
        let shipDate: String
        let status: Status
        var complete: Bool = false
    }

    struct Error: Decodable {
        let message: String
    }
}
```

In the final step, we once again need to indicate the decoding logic of Postie, to expect a JSON request body, which is done by changing the Decodable protocol of the type Order to be a JSONDecodable instead (same for Error).

```swift
enum Definitions {
    struct Order: Encodable, JSONDecodable {
        enum Status: String, Encodable, Decodable {
            case placed
            case approved
            case delivered
        }

        let id: Int64
        let petId: Int64
        let quantity: Int32
        let shipDate: String
        let status: Status
        var complete: Bool = false
    }

    struct Error: JSONDecodable {
        let message: String
    }
}
```

Good job! Let’s give ourselves a pat on the back, our API definition is ready💪🏼

### Sending the Request

Using the request definition is easy. All you have to do is create an object CreateStoreOrder and send it using the HTTPAPIClient we declared earlier.

> **Note: **Postie uses the asynchronous event framework [Combine](https://developer.apple.com/documentation/combine) for it’s communication. As it uses the underlying URLSession other async patterns are (if requested) possible too.

```swift
// Create the request
let request = CreateStoreOrder(body: .init(
    id: 1,
    petId: 2,
    quantity: 3,
    shipDate: "2021-07-04T09:23:00Z",
    status: .placed))
// Send the request
client.send(request)
    .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
            print("Successfully sent request!")
        case .failure(let error):
            print("Something went wrong:", error)
        }
    }, receiveValue: { response in
        print("Status Code:", response.statusCode)
        if let body = response.body {
            print("Successful response body:", body)
        } else if let errorBody = response.body {
            print("Error response body:", errorBody)
        }
    })
```

As our CreateStoreOrder has an associated Response type, we won’t have to define the expected response type again or worry about its parsing logic.

From now on we simply **use** our API.

## Many more features

There are many more features available, but I couldn’t cover them all in this story. It’s highly recommend that you checkout the vast [README guide](https://github.com/kula-app/Postie/) to see the full feature-set.

Just to give you a glance of what else is available:

- `@RequestHeader` defines request headers
- `@ReponseHeader` to read a specific header from the response
- `@QueryItem` to add typed fields to the request URL query
- `@RequestPathParameter` to set typed parameters in the URL (such as the petId from our example)

... and more!

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

Even tough the package is still under active development, we are going to use it for production apps at [kula](https://www.kula.app/)[kula](https://www.kula.app/) and [techprimate](https://techprimate.com) to validate the usage, eventually bumping it to version 1.0.0

## Conclusion & Contribution

Follow the [repository](https://github.com/kula-app/Postie/) and submit your feature requests. It started as an Open Source project and should remain one, so we all can profit from each other. Found a bug? [Let us know!](https://github.com/kula-app/Postie/issues/new)

I also would love to hear what you think about this project. Follow me on [Twitter](https://twitter.com/philprimes) and feel free to drop a DM with your thoughts.
Also checkout [my other articles](philprime.dev/blog). You have a specific topic you want me to cover? Let me know! 😃
