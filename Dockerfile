FROM ruby:3.0
MAINTAINER dwalters@engineyard.com

RUN apt-get update && apt-get install -y \
  build-essential \
  rsync \
  wamerican \
  nodejs \
  vim

RUN mkdir -p /app
WORKDIR /app

COPY . ./
#RUN gem install bundler && bundle install
RUN bundle install

CMD ["bash"]
