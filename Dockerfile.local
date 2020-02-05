FROM ruby:2.6.5
ENV LANG C.UTF-8
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - && apt-get -y dist-upgrade && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*
RUN mkdir /app
WORKDIR /app
