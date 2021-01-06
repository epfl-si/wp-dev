# Testing Wordpress @ EPFL

Here you will find the tools to use the [`cucumber`](https://github.com/cucumber/cucumber-js) Behavior-Driven Development (BDD) testing framework in concert with the Headless Chrome Node.js API [`puppeteer`](https://github.com/puppeteer/puppeteer) for the purpose of integration testing.

## Getting Started

### With a docker image

Run the docker image in headless mode

```bash
npm run docker
```


### Locally

Run tests in a live Chromium instance on your `https://wp-httpd` local server

1. Install dependencies:

```bash
npm i
```

2. Run integration test suite:

```bash
npm run test
```
