# frozen_string_literal: true

require 'erb'

module MatrixInviteBot
  class Community
    attr_reader :id, :client

    def initialize(client, community_id)
      raise ArgumentError, 'Must be given a Client instance' unless client.is_a? MatrixSdk::Client

      community_id = MatrixSdk::MXID.new community_id unless community_id.is_a?(MatrixSdk::MXID)
      raise ArgumentError, 'community_id must be a valid Community ID' unless community_id.group?

      @client = client
      @id = community_id.to_s
    end

    def accept_invite
      client.api.request :put, :client_r0, "/groups/#{clean_id}/self/accept_invite", body: {}
    end

    def join
      client.api.request :put, :client_r0, "/groups/#{clean_id}/self/join", body: {}
    end

    def is_admin?
      client.api.request(:get, :client_r0, "/groups/#{clean_id}/users")[:chunk]\
        .find { |ch| ch[:user_id] == client.mxid.to_s }[:is_privileged]
    end

    def joined?
      client.api.request(:get, :client_r0, '/joined_groups').groups.include? id
    end

    def includes_user?(user)
      user = client.get_user(user) unless user.is_a? MatrixSdk::User

      invited_members.map(&:id).include?(user.id) || joined_members.map(&:id).include?(user.id)
    end

    def invited_members
      client.api.request(:get, :client_r0, "/groups/#{clean_id}/invited_users")[:chunk]\
        .map { |ch| client.get_user(ch[:user_id]) }
    end

    def joined_members
      client.api.request(:get, :client_r0, "/groups/#{clean_id}/users")[:chunk]\
        .map { |ch| client.get_user(ch[:user_id]) }
    end

    def rooms
      client.api.request(:get, :client_r0, "/groups/#{clean_id}/rooms")[:chunk]\
        .map { |ch| client.ensure_room(ch[:room_id]) }
    end

    def invite_user(user_id)
      user_id = user_id.id if user_id.is_a?(MatrixSdk::User)
      user_id = MatrixSdk::MXID.new user_id unless user_id.is_a?(MatrixSdk::MXID)
      raise ArgumentError, 'user_id must be a valid User ID' unless user_id.user?

      user_id = ERB::Util.url_encode user_id.to_s

      client.api.request(:put, :client_r0, "/groups/#{clean_id}/admin/users/invite/#{user_id}", body: {})
    end

    private

    def clean_id
      ERB::Util.url_encode id.to_s
    end
  end
end
