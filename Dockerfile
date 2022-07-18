FROM ruby:3.1-alpine
WORKDIR /scenic-dependencies
RUN apk add --no-cache bash gcc git libc6-compat make musl-dev postgresql-dev sqlite-dev tzdata
COPY . .
RUN bin/setup
CMD ["rake"]
