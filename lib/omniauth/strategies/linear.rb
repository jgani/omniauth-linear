require 'omniauth-oauth2'
require "graphql/client"
require "graphql/client/http"

module OmniAuth
  module Strategies
    class Linear < OmniAuth::Strategies::OAuth2
      option :client_options, {
        site: 'https://api.linear.app/graphql',
        authorize_url: 'https://linear.app/oauth/authorize',
        token_url: 'https://api.linear.app/oauth/token',
        response_type: 'code',
      }

      option :auth_token_params, {
        grant_type: 'authorization_code',
      }

      option :actor, 'user'

      def request_phase
        super
      end

      def authorize_params
        super.tap do |params|
          %w[client_options].each do |v|
            if request.params[v]
              params[v.to_sym] = request.params[v]
            end
          end
          %w[actor prompt].each do |v|
            params[v.to_sym] = options[v] if options[v]
          end
        end
      end

      uid { me['viewer']['id'] }

      extra do
        { raw_info: raw_info, me: me['viewer'], organization: me['organization'], actor: options[:actor] }
      end

      def raw_info
        @raw_info ||= {}
      end

      info do
        {
          id: me['viewer']['id'],
          name: me['viewer']['name'],
          email: me['viewer']['email'],
          organization_id: me['organization']['id'],
          organization_name: me['organization']['name']
        }
      end

      def me
        @me ||= begin
          http = GraphQL::Client::HTTP.new(options.client_options.site) do |obj|
            def headers(context)
              {"Authorization" => "Bearer #{context[:token]}"}
            end
          end
          schema = GraphQL::Client.load_schema(http)
          client = GraphQL::Client.new(schema: schema, execute: http)
          client.allow_dynamic_queries = true

          gql = client.parse <<~GRAPHQL
            query {
              organization {
                id
                name
              }
              viewer {
                id
                name
                email
              }
            }
          GRAPHQL
          response = client.query(gql, context: {token: access_token.token})
          response.data.to_h
        end
      end

      def callback_url
        "#{full_host}#{callback_path}"
      end
    end
  end
end

OmniAuth.config.add_camelization 'linear', 'Linear'
