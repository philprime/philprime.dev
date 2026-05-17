---
layout: post.liquid
title: "Standardized Health Endpoint in Go"
date: 2026-05-19 09:00:00 +0200
categories: blog
tags: [Go, Kubernetes, Health Checks, Observability, Open Source]
description: "Building a reusable Go package for standardized health endpoints based on the IETF health check RFC, with separate liveness, readiness, and health endpoints for Kubernetes."
excerpt: "Introducing go-health, my first open-source Go package that implements the IETF health check RFC with reusable checks and clear separation of liveness, readiness, and health endpoints for Kubernetes services."
keywords: "Go health endpoint, Kubernetes health checks, liveness probe, readiness probe, healthz, livez, readyz, IETF health check RFC, draft-inadarei-api-health-check, Go observability, Go open source"
image: /assets/blog/2026-05-19-standardized-health-endpoint-in-go/hero.webp
author: Philip Niedertscheider
featured: true
---

After years of developing backend services, one need has consistently shown up in every single project: a health endpoint to know if the service is up and running, or if it is experiencing issues.

Especially after learning about containerization and replicated orchestration, my understanding grew that a health endpoint is not just a nice-to-have, but instead a must-have to ensure reliability and observability.

Now for health endpoints the core logic is straightforward: it should return a HTTP 200 status code if the service is healthy, and a HTTP 503 status code if the service is unhealthy.
But that's already thinking in two extremes, even though there is also the state of being "degraded" where the service is still up but not fully functional.

Over the years none of the health endpoints I have implemented were the same.
Some returned a simple "OK" string, some returned a JSON object with more details, and some even had different endpoints for liveness and readiness once I started working with Kubernetes.

On top of that, my programming language and framework of choice kept shifting, as I moved on from Java SpringBoot to Nest.js, and rather recently to my new favorite Go, which made me implement health endpoints in different ways and with different libraries.

A couple of years ago I stumbled upon the RFC [draft-inadarei-api-health-check-06](https://datatracker.ietf.org/doc/html/draft-inadarei-api-health-check-06), which defines a standardized way to implement health endpoints, structuring the response in a consistent way and providing a clear contract for clients consuming the health endpoint.

Today I am bringing it all together with my first ever Go package [github.com/kula-app/go-health](https://pkg.go.dev/github.com/kula-app/go-health), which offers an agnostic, standardized, and easy-to-use implementation of the health endpoint based on the RFC.

## The RFC

While the RFC is still a draft and never got finalized, I still see its potential and started to adopt it in many of my projects as the standard way to implement health and readiness endpoints.

**To summarize the key points of the RFC:**

The endpoint accepts a HTTP GET request and returns a JSON response with the `Content-Type` header set to `application/health+json`.
This object contains a `status` field which can be one of three values:

- `pass`: healthy (acceptable aliases: "ok" to support Node's Terminus and "up" for Java's SpringBoot)
- `fail`: unhealthy (acceptable aliases: "error" to support Node's Terminus and "down" for Java's SpringBoot)
- `warn`: healthy, but with some concerns (the case of being "degraded")

The status is also reflected in the HTTP status code: `200-300` for `pass` and `warn`, and `400-500` for `fail`.
This allows clients to easily determine the health status of the service by looking at the HTTP status code, while also providing more detailed information in the response body if needed.

Now as a service usually has multiple sub-services and dependencies, the other key idea of the RFC is the `checks` field, which is an object containing the results of individual health checks for each component of the service.
Each key is a string that identifies both the component and the measurement type, e.g. _"cassandra:responseTime"_ or _"cpu:utilization"_, and the value is an array of objects, where each object represents a single check result for that component and measurement type.

As each component can have multiple checks, e.g. a database might check multiple replica nodes, the value is an array of sub-components.
For each sub-component, the RFC defines a set of fields to provide detailed information which allows us to easily understand the health status, with the most important ones being:

- `componentId`: a unique identifier for checked sub-component/dependency of a service, e.g. the ID of a database node.
- `componentType`: a string that categorizes the type of component being checked, e.g. "datastore", "system", "cache", etc.
- `observedValue`: the actual value observed during the health check, which can be used to determine the health status based on predefined thresholds, e.g. CPU utilization percentage, response time in milliseconds, etc.
- `status`: the health status of the component, which can be one of "pass", "warn", or "fail", following the same semantics as the overall status field.

Bringing it all together, here is an example of a health endpoint response from the RFC:

```json
{
  "status": "pass",
  "checks": {
    "cassandra:responseTime": [
      {
        "componentId": "dfd6cf2b-1b6e-4412-a0b8-f6f7797a60d2",
        "componentType": "datastore",
        "observedValue": 250,
        "observedUnit": "ms",
        "status": "pass",
        "affectedEndpoints": [
          "/users/{userId}",
          "/customers/{customerId}/status",
          "/shopping/{anything}"
        ],
        "time": "2018-01-17T03:36:48Z",
        "output": ""
      }
    ],
    "cassandra:connections": [
      {
        "componentId": "dfd6cf2b-1b6e-4412-a0b8-f6f7797a60d2",
        "componentType": "datastore",
        "observedValue": 75,
        "status": "warn",
        "time": "2018-01-17T03:36:48Z",
        "output": "",
        "links": {
          "self": "http://api.example.com/dbnode/dfd6cf2b/health"
        }
      }
    ],
    "uptime": [
      {
        "componentType": "system",
        "observedValue": 1209600.245,
        "observedUnit": "s",
        "status": "pass",
        "time": "2018-01-17T03:36:48Z"
      }
    ],
    "cpu:utilization": [
      {
        "componentId": "6fd416e0-8920-410f-9c7b-c479000f7227",
        "node": 1,
        "componentType": "system",
        "observedValue": 85,
        "observedUnit": "percent",
        "status": "warn",
        "time": "2018-01-17T03:36:48Z",
        "output": ""
      },
      {
        "componentId": "6fd416e0-8920-410f-9c7b-c479000f7227",
        "node": 2,
        "componentType": "system",
        "observedValue": 85,
        "observedUnit": "percent",
        "status": "warn",
        "time": "2018-01-17T03:36:48Z",
        "output": ""
      }
    ],
    "memory:utilization": [
      {
        "componentId": "6fd416e0-8920-410f-9c7b-c479000f7227",
        "node": 1,
        "componentType": "system",
        "observedValue": 8.5,
        "observedUnit": "GiB",
        "status": "warn",
        "time": "2018-01-17T03:36:48Z",
        "output": ""
      },
      {
        "componentId": "6fd416e0-8920-410f-9c7b-c479000f7227",
        "node": 2,
        "componentType": "system",
        "observedValue": 5500,
        "observedUnit": "MiB",
        "status": "pass",
        "time": "2018-01-17T03:36:48Z",
        "output": ""
      }
    ]
  }
}
```

## Implementing the RFC in Go

While recently working on some side-projects written in Go, I once again created the `/healthz` endpoint using this RFC as my reference.
As I am continuously learning the best-practices of Kubernetes, I then realized that a single health endpoint [is deprecated since Kubernetes v1.16](https://kubernetes.io/docs/reference/using-api/health-checks/#api-endpoints-for-health), and instead we should rely on two separate endpoints `/livez` and `/readyz`.

The idea behind having two different endpoints is that the liveness endpoint (`/livez`) is used to determine if the service is alive or if the pod needs to be restarted, while the readiness endpoint (`/readyz`) is used to determine if the service is ready to receive traffic from a load balancer.

This also means we need to bridge the gap between the RFC and the behaviour expected by Kubernetes, as Kubernetes will restart a pod if its `/livez` endpoint returns a non-200 status code, which will happen if our health endpoint returns a `fail` status.

On the other hand, if our health endpoint returns a `warn` status, Kubernetes will still consider the pod as alive but and ready to receive traffic, which might not be what we want if the warning is about a critical dependency that is degraded.

Let's visualize this with an example of a server using a database which is experiencing some issues, e.g. high response time or high number of connections, resulting in a `fail` status for the database checks in our health endpoint.

```json
{
  "status": "fail",
  "checks": {
    "system:uptime": [
      {
        "componentType": "system",
        "observedValue": 1209600.245,
        "observedUnit": "s",
        "status": "pass",
        "time": "2018-01-17T03:36:48Z"
      }
    ],
    "cassandra:responseTime": [
      {
        "componentId": "dfd6cf2b-1b6e-4412-a0b8-f6f7797a60d2",
        "componentType": "datastore",
        "observedValue": 250,
        "observedUnit": "ms",
        "status": "fail",
        "time": "2018-01-17T03:36:48Z"
      }
    ]
  }
}
```

For this example the overall status is `fail`, because the database check's `fail` status is propagated up, and the returned HTTP status code will be `503`.

If we use this health endpoint for the liveness check, Kubernetes will consider the pod as unhealthy and will restart it, even though our service might recover shortly after and be able to serve traffic again.

But, during this time we do not want Kubernetes to send traffic to this pod, so it's suitable for the readiness check to return a failed status.

This means that we need to have two different checks for liveness and readiness, where the liveness should focus on the service being started properly, i.e. the service is not crashing during startup, while the readiness should focus on the service being able to perform work.

**Liveness Check `GET /livez`:**

```json
{
  "status": "pass",
  "checks": {
    "system:uptime": [
      {
        "componentType": "system",
        "observedValue": 1209600.245,
        "observedUnit": "s",
        "status": "pass",
        "time": "2018-01-17T03:36:48Z"
      }
    ]
  }
}
```

**Readiness Check `GET /readyz`:**

```json
{
  "status": "fail",
  "checks": {
    "system:uptime": [
      {
        "componentType": "system",
        "observedValue": 1209600.245,
        "observedUnit": "s",
        "status": "pass",
        "time": "2018-01-17T03:36:48Z"
      }
    ],
    "cassandra:responseTime": [
      {
        "componentId": "dfd6cf2b-1b6e-4412-a0b8-f6f7797a60d2",
        "componentType": "datastore",
        "observedValue": 250,
        "observedUnit": "ms",
        "status": "fail",
        "time": "2018-01-17T03:36:48Z"
      }
    ]
  }
}
```

Now as soon as the database recovers and the `cassandra:responseTime` check returns a `pass` status, the overall status of the readiness check will also return a `pass` status, and Kubernetes will start sending traffic to this pod again.

As we might have additional checks which are informational, e.g. above-threshold CPU utilization, but they are not critical for the service, I decided to keep the `/healthz` endpoint as a separate endpoint which returns the overall health status, so it can be used by monitoring tools unrelated to Kubernetes.

**Health Check `GET /healthz`:**

```json
{
  "status": "fail",
  "checks": {
    "system:uptime": [
      {
        "componentType": "system",
        "observedValue": 1209600.245,
        "observedUnit": "s",
        "status": "pass",
        "time": "2018-01-17T03:36:48Z"
      }
    ],
    "cassandra:responseTime": [
      {
        "componentId": "dfd6cf2b-1b6e-4412-a0b8-f6f7797a60d2",
        "componentType": "datastore",
        "observedValue": 50,
        "observedUnit": "ms",
        "status": "pass",
        "time": "2018-01-17T03:36:48Z"
      }
    ],
    "cpu:utilization": [
      {
        "componentId": "6fd416e0-8920-410f-9c7b-c479000f7227",
        "node": 1,
        "componentType": "system",
        "observedValue": 85,
        "observedUnit": "percent",
        "status": "warn",
        "time": "2018-01-17T03:36:48Z",
        "output": ""
      }
    ]
  }
}
```

In simpler terms: the health endpoint contains all checks, the readiness endpoint the critical checks to serve traffic, and the liveness endpoint the critical checks to keep the service alive.

### Bringing it all together

As I have multiple Go services running with different external dependencies, I duplicated my default implementation over time into multiple projects... until today when I decided it's finally time to create a reusable package.

Being an advocate for open-source software, I decided that this package should be available for everyone to use under the name of [`github.com/kula-app/go-health`](https://pkg.go.dev/github.com/kula-app/go-health).

When thinking about the architecture and patterns I tried to stick with the RFC as much as possible: checks should be defined as injectable logic returning one or multiple result objects.

For the checks themselves, I wanted them to be reusable and configurable, so I created a `Check` struct which is self-contained and offers a `Run` function to execute the check and return the results.

```go
type Check struct {
    Name          string
    ComponentType string
    Timeout       time.Duration
    Run           func(ctx context.Context) []Result
}
```

To make sure we can decide which checks should be included in the liveness, readiness, and health endpoints, I created an `Engine` which offers three registration methods:

```go
// Adds a check to the full health endpoint only
func (e *Engine) RegisterHealthCheck(c Check) { ... }

// Adds a check to both the health and readiness endpoints
func (e *Engine) RegisterReadinessCheck(c Check) { ... }

// Adds a check to the health, readiness, and liveness endpoints
func (e *Engine) RegisterLivenessCheck(c Check) { ... }
```

On top of that I extracted all the health checks I am using in my services into reusable checks which can be easily configured and used across different projects:

- `dbcheck` for performing a ping check against a SQL database
- `httpcheck` to perform a HTTP request against an endpoint and check the response status code
- `tcpcheck` to perform a TCP connection check against a host and port
- `s3check` to see if an AWS S3 bucket is accessible
- `redischeck` to see if a Redis instance (single node or cluster) is accessible

... and the list will continue to grow as I add more checks and more people start contributing to the project.

In case custom ones are needed, they are also very easy to create by just constructing a `Check` value and providing the logic in the `Run` function:

{% raw %}

```go
c := core.Check{
    Name:          "queue:depth",
    ComponentType: "datastore",
    Timeout:       2 * time.Second,
    Run: func(ctx context.Context) []core.Result {
        depth, err := queue.Depth(ctx)
        if err != nil {
            return []core.Result{{Status: core.StatusFail, Output: err.Error()}}
        }
        if depth > 10_000 {
            return []core.Result{{
                Status:        core.StatusWarn,
                ObservedValue: depth,
                ObservedUnit:  "messages",
                Output:        "queue depth above warning threshold",
            }}
        }
        return []core.Result{{
            Status:        core.StatusPass,
            ObservedValue: depth,
            ObservedUnit:  "messages",
        }}
    },
}
```

{% endraw %}

### Conclusion

To conclude, having a standardized health endpoint across all of my services is a great step towards a maintainable and observable server architecture.
With reusable checks and a clear pattern to create new ones, I can now build them once and use them across projects, reducing the amount of duplicated code to maintain.
Having it as a public open source package also allows other developers to chime in and contribute to it, making it a win-win for everyone.

The library is now in early development, and there will be a couple of breaking changes along the way.
Feel free to try it out and send me a message on [X](https://x.com/philprimes) with what you think about it!
