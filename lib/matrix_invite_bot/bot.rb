# frozen_string_literal: true

BOT_FILTER = {
  presence: { types: [] },
  account_data: { types: [] },
  room: {
    ephemeral: { types: [] },
    state: {
      types: ['m.room.member'],
      lazy_load_members: true
    },
    timeline: {
      types: ['m.room.message', 'm.room.member']
    },
    account_data: { types: [] }
  }
}.freeze

SYNC_INTERVAL = 8 * 60 * 60 # Default: 8h

HELP_TEXT = <<~HELP
  Usage;
    !invite help
      Show this text
    !invite status
      Show current invite handling status for this room
    !invite refresh
      Refresh the membership for all currently joined members in this room
    !invite link +community:example.com
      Links the given community to this room
    !invite unlink
      Unlinks any communities from this room
HELP

module MatrixInviteBot
  class Bot
    include MatrixSdk::Logging

    attr_reader :client

    def initialize(homeserver:, access_token:, state_type: 'se.liu.invite_bot')
      @client = MatrixSdk::Client.new homeserver, access_token: access_token, client_cache: :all
      @state_type = state_type
      @tracked = []
    end

    def run
      # Accept all invites
      client.on_invite_event.add_handler do |ev|
        logger.info "Received invite to #{ev[:room_id]}, joining..."
        client.join_room(ev[:room_id])
      end
      client.on_event.add_handler('m.room.message', 'messages') { |ev| on_message_event(ev) }

      perform_clean_sync
      update_tracked_rooms
      @tracked.each do |room|
        ensure_community(room)
        recheck_members(room, max_rooms: 100)
      rescue MatrixSdk::MatrixError => e
        logger.error "Failed to ensure community for #{room.id};\n#{e.class}: #{e}\n#{e.backtrace[0..10].join "\n"}"
      end

      filter = deep_copy(BOT_FILTER)
      filter[:room][:state][:types] << @state_type

      last_sync = Time.now
      loop do
        client.sync filter: BOT_FILTER

        if Time.now - last_sync >= SYNC_INTERVAL
          update_tracked_rooms
          last_sync = Time.now
        end
      rescue MatrixSdk::MatrixError => e
        logger.error e
      end
    end

    private

    def on_member_event(event)
      return if %w[invite knock].include? event.content[:membership]

      logger.info "Seen member event for #{event.state_key} in #{event.room_id} - #{event.content[:membership]}"

      room = client.ensure_room event.room_id
      community = room.community

      return unless event.content[:membership] == 'join'
      return if event.state_key == client.mxid.to_s
      return if room.members.find { |u| u.id == event.state_key } # Already seen the user join this room

      invite_user(community, event.state_key) # even_if_leave: true # TODO: Config
    end

    def on_message_event(event)
      return unless event.content[:msgtype] == 'm.text'
      return unless event.content[:body].start_with? '!invite '

      room = client.ensure_room event.room_id
      sender = client.get_user event.sender

      pl = client.api.get_power_levels(room.id)
      sender_pl = pl.users[sender.id.to_s.to_sym] || pl.users_default || 0

      return unless sender_pl >= 100

      command = event.content[:body][8..-1]
      return if command.empty?

      logger.info "Handling command #{command.inspect} from #{sender.id} in room #{room.id}..."
      command, *args = command.split(' ')

      begin
        case command
        when 'help'
          room.send_notice HELP_TEXT
        when 'status'
          if room.instance_variables.include? :@community
            community_id = room.community.id
            room.send_notice "Currently tracking community #{community_id} for this room."
          else
            room.send_notice 'Not tracking any community for this room.'
          end
        when 'refresh'
          unless room.instance_variables.include?(:@community) && room.community
            room.send_notice 'Not tracking any community for this room.'
            return
          end

          ensure_community(room)
          recheck_members(room, max_rooms: 100)

          room.send_notice 'Refreshed membership for the linked community and rooms.'
        when 'link'
          community_id = MatrixSdk::MXID.new args.first
          raise 'Not a valid community ID' unless community_id.group?
          raise 'Not allowed to add necessary state data, give moderator rights?' unless\
            (pl.users[client.mxid.to_s.to_sym] || pl.users_default || 0) >= (pl.events[@state_type.to_sym] || pl.state_default || 50)

          room.instance_variable_set :@community, MatrixInviteBot::Community.new(client, community_id.to_s)
          unless room.respond_to? :community
            room.instance_eval do
              def community
                @community
              end
            end
          end
          ensure_community(room)

          room.send_notice('Not allowed to invite users to given community, give admin in the community if that functionality is required.') unless room.community.admin?

          recheck_members(room, max_rooms: 100)

          client.api.send_state_event(room.id, @state_type, { community_id: args.first })

          room.on_state_event.add_handler('m.room.member', 'membership') { |ev| on_member_event(ev) }
          @tracked << room

          room.send_notice "Now tracking community #{community_id} for this room."
        when 'unlink'
          if room.instance_variables.include?(:@community) && room.community
            raise 'Not allowed to add necessary state data, give moderator rights?' unless\
              (pl.users[client.mxid.to_s.to_sym] || pl.users_default || 0) >= (pl.events[@state_type.to_sym] || pl.state_default || 50)

            community_id = room.community.id
            room.instance_variable_set :@community, nil
            client.api.send_state_event(room.id, @state_type, {})
            room.on_state_event.remove_handler('membership')

            room.send_notice "No longer tracking community #{community_id} for this room."
          else
            room.send_notice 'Not tracking any community for this room.'
          end
        else
          room.send_notice "No idea what #{command.inspect} is, try \"!invite help\""
        end
      rescue MatrixSdk::MatrixError => e
        room.send_notice "Failed to handle request. #{e}"
        logger.error e
      rescue RuntimeError => e
        room.send_notice "Failed to handle request. #{e}"
        logger.error e
      rescue StandardError => e
        room.send_notice "Failed to handle request. #{e.class}: #{e}"
        logger.error e
        raise
      end
    end

    def perform_clean_sync
      logger.info 'Performing clean sync...'
      empty_sync = deep_copy(BOT_FILTER)
      empty_sync[:room].map { |_k, v| v[:types] = [] }
      client.sync filter: empty_sync
    end

    def update_tracked_rooms
      logger.info 'Updating tracked rooms...'
      @tracked.each do |room|
        room.on_state_event.remove_handler('membership')
      end

      client.instance_variable_set :@rooms, {}
      @tracked = client.rooms.select do |room|
        state = client.api.get_room_state(room.id, @state_type)
        return false if state.empty?

        room.instance_variable_set :@community, MatrixInviteBot::Community.new(client, state[:community_id])
        room.instance_eval do
          def community
            @community
          end
        end

        true
      rescue MatrixSdk::MatrixNotFoundError
        false
      end

      logger.info "Tracking the following rooms;\n#{@tracked.map { |r| "#{r.id} - #{r.community.id}" }.join("\n")}"

      @tracked.each do |room|
        room.on_state_event.add_handler('m.room.member', 'membership') { |ev| on_member_event(ev) }
      end
    end

    def ensure_community(room)
      community = room.community
      logger.info "Ensuring community #{community.id} is joined... (from room #{room.id})"

      unless community.joined?
        begin
          community.accept_invite
        rescue MatrixSdk::MatrixError
          community.join
        end
      end

      logger.info "Ensuring rooms for community #{community.id} are joined..."

      # TODO: Improve this?
      rooms = community.rooms
      valid_servers = ([MatrixSdk::MXID.new(community.id).homeserver] + rooms.map { |r| MatrixSdk::MXID.new(r.id).homeserver }).uniq
      joined_rooms = client.rooms.map(&:id)

      rooms.each do |rroom|
        next if joined_rooms.include? rroom.id

        client.join_room rroom, server_names: valid_servers
      end

      return unless community.admin?

      logger.info "Ensuring members for community #{community.id} are invited..."

      members = community.invited_members + community.joined_members
      room.members.clear
      room.joined_members.each do |member|
        next if members.map(&:id).include? member.id

        community.invite_user member
      end
    end

    def recheck_members(room, max_rooms: 15)
      community = room.community
      logger.info "Rechecking members for #{community.id} from room #{room.id}..."

      members = room.all_members(membership: :join).map(&:id)
      other_rooms = community.rooms

      other_rooms.sample(max_rooms).each do |other_room|
        next if other_room.id == room.id

        diff = members - other_room.all_members.map(&:id)
        diff.each do |user|
          invite_user(community, user, community: false, rooms: other_rooms)
        end
      end
    end

    def invite_user(community_id, user_id, community: true, even_if_leave: false, rooms: nil)
      logger.info "Inviting user #{user_id} to #{community_id.id}#{community ? ' and' : nil} rooms..."
      rooms ||= community_id.rooms
      user_id = client.get_user(user_id.to_s) unless user_id.is_a? MatrixSdk::User

      community_id.invite_user user_id if community && community_id.admin? && !community_id.includes_user?(user_id)

      params = {}
      params[:not_membership] = :leave if even_if_leave

      rooms.each do |room|
        next if room.all_members(**params).map(&:id).include? user_id.id

        room.invite_user user_id
      end
    end

    def deep_copy(hash)
      Marshal.load(Marshal.dump(hash))
    end
  end
end
