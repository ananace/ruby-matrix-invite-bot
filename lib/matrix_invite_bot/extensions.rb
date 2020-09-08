# frozen_string_literal: true

unless MatrixSdk::Room.instance_methods.include? :all_members
  module MatrixSdk
    class Room
      def all_members(**params)
        # client.api.get_room_members(id, **params)[:chunk].map { |ch| client.get_user(ch[:state_key]) }

        room_id = ERB::Util.url_encode id.to_s
        client.api.request(:get, :client_r0, "/rooms/#{room_id}/members", query: params)[:chunk].map { |ch| client.get_user(ch[:state_key]) }
      end
    end
  end
end

unless MatrixSdk::Room.instance_methods.include? :put_state_event
  module MatrixSdk
    class Room
      def put_state_event(event)
        fire_state_event MatrixEvent.new(self, event)
      end
    end
  end

  MatrixSdk::Client.class_eval do
    alias_method :handle_state_broken, :handle_state
    def handle_state(room_id, state_event)
      handle_state_broken(room_id, state_event)

      ensure_room(room_id).send :put_state_event, state_event
    end
  end
end
