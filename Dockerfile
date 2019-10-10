FROM ruby:2.6-alpine

# throw errors if Gemfile has been modified since Gemfile.lock
#RUN bundle config --global frozen 1

WORKDIR /usr/src/app

#COPY Gemfile Gemfile.lock ./
#RUN bundle install

COPY . .

CMD ["./fetch_metadata.rb"]
