# frozen_string_literal: true

require 'active_support/log_subscriber'

module ROM
  module SQL
    class RailsLogSubscriber < ActiveSupport::LogSubscriber
      as_version =
        begin
          require 'active_support/gem_version'
          ActiveSupport.gem_version
        rescue LoadError
          nil
        end

      COLOR_OPTION =
        if as_version && as_version >= ::Gem::Version.new('7.1.2')
          { bold: true }
        else
          true
        end

      def sql(event)
        return unless logger.debug?

        payload = event.payload

        name = format('%<name>s (%<duration>.1fms)', name: payload[:name], duration: event.duration)
        sql  = payload[:sql].squeeze(' ')
        binds = payload[:binds].to_a.inspect if payload[:binds]

        if odd?
          name = color(name, :cyan, COLOR_OPTION)
          sql  = color(sql, nil, COLOR_OPTION)
        else
          name = color(name, :magenta, COLOR_OPTION)
        end

        debug "  #{name}  #{sql}  #{binds}"
      end

      attr_reader :odd_or_even
      private :odd_or_even
      def odd?
        @odd_or_even = !odd_or_even
      end
    end
  end
end

ROM::SQL::RailsLogSubscriber.attach_to(:rom)
