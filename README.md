# Matrix Invite Bot

A simple bot that tracks community - and community room - membership based on a "reception" room.

Invite your users to one room with 3PIDs and MXIDs, once they accept they'll automatically be invited to the linked community, and all rooms that are part of the community.

**TODO**:
- Uninvites?
- Kicks? Bans?

## Usage

```
Usage: matrix_invite_bot [options]
        --homeserver URL             Sets the homeserver to connect to
        --access-token TOKEN         Sets the access token to use when communicating with the homeserver.
                                     Also read from ACCESS_TOKEN environment variable.
        --state-type TYPE            Change the state type the bot should look for.
                                     Default: se.liu.invite_bot
        --help                       Display this output
    -v, --verbose                    Enable verbose (debug) output
```

Once the bot is running, invite it to what is to be the main room - and the associated community and rooms - and use the command `!invite link +community:example.com` in the main room to set up the link.

## Contributing

The project lives on https://gitlab.liu.se/ITI/matrix-invite-bot - but issues and PRs are also welcome on GitHub at https://github.com/ananace/ruby-matrix-invite-bot

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
