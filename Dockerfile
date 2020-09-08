FROM ruby AS builder

COPY Gemfile matrix_invite_bot.gemspec README.md LICENSE.txt /app/
COPY bin/ /app/bin/
COPY lib/ /app/lib/
WORKDIR /app

RUN bundle install -j4 \
 && gem build matrix_invite_bot.gemspec

FROM ruby

COPY --from=builder /app/matrix_invite_bot*.gem /

RUN gem install /matrix_invite_bot*.gem\
 && rm /*.gem

ENTRYPOINT [ "/usr/local/bundle/bin/matrix_invite_bot" ]
