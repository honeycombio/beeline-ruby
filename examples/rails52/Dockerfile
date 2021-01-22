FROM ruby:2.5
RUN apt-get update -qq && apt-get install -y nodejs sqlite3
RUN gem install bundler
WORKDIR /myapp
ENV BEELINE_FROM_RUBYGEMS=true
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
COPY vendor/libhoney-rb /myapp/vendor/libhoney-rb
RUN bundle install
COPY . /myapp

EXPOSE 3000
CMD [ "bundle", "exec", "rails", "server", "-p", "3000", "-b", "0.0.0.0" ]
