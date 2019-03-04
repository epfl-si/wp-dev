FROM node:latest

WORKDIR /opt/app
RUN mkdir /test-output

# Install Google Chrome to grab its dependencies (puppeteer will download
# a version of Chromium for itself regardless)
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
RUN apt-get update && apt-get install -y google-chrome-stable

# "npm install" does the bulk of the work, so do it in the first few
# lines of the Dockerfile (so that it doesn't need re-doing for every
# change)
ADD package.json package-lock.json /opt/app/
RUN npm install

ADD . /opt/app/

ENTRYPOINT ["/opt/app/bin/docker-entrypoint"]
