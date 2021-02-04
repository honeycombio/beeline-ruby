# Honeycomb Beeline Rails 5.2 Sample Application

## Getting Started

* Have [Docker Desktop](https://www.docker.com/products/docker-desktop) or some form of Docker Compose available.
* [Sign up for a honeycomb account](https://ui.honeycomb.io/signup).
* Set environment variables!
    * `HONEYCOMB_WRITE_KEY`: the value of the writekey for your Honeycomb team
    * `HONEYCOMB_DATASET`: (optional) a name for a dataset within your team you would like this application's data to go to.
      If left unset, data will appear in your team under a `rails52example` dataset.
* Run `docker-compose up`!
* Visit the [sample application site](http://localhost:3000)
* Create some bees!
* Load your [Honeycomb dashboard](https://ui.honeycomb.io) and see the built-in instrumentation!
  * An interesting query:
    * VISUALIZE: COUNT, HEATMAP(duration_ms)
    * GROUP BY: name, request.header.user_agent, request.host, request.header.x_forwarded_for
    * ORDER BY: name asc


## What services are running in this example?

* on an interal-only network with no direct internet access:
  * a Rails web service to store bees
  * a Sidekiq background job runner with a job scheduled to visit the bees endpoint periodically
  * a Redis instance for Sidekiq
* on both a bridged network and the internal network:
  * a Squid proxy:
    * reverse proxy connections back to the Rails web app on localhost:3000
    * provides authenticated HTTP/S forwarding to the internet for the services above
