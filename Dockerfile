FROM ruby:3.4-alpine
WORKDIR /scenic-cascade
RUN apk add --no-cache bash gcc git libc6-compat linux-headers make musl-dev postgresql-dev tzdata yaml-dev
COPY . .
RUN bin/setup
CMD ["bundle", "exec", "rake"]
