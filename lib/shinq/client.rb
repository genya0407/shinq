require 'sql-maker'
require 'sql/maker/quoting'
require 'active_support/core_ext/hash/keys'

module Shinq
  class Client
    def self.builder
      @builder ||= SQL::Maker.new(driver: 'mysql', auto_bind: true)
    end

    def self.enqueue(table_name: , job_id: , args:)
      case args
      when Hash
        sql = builder.insert(table_name, args.merge(
          job_id: job_id,
          enqueued_at: Time.now
        ))
        Shinq.connection.query(sql)
      else
        raise ArgumentError, "Queue should be Hash"
      end
    end

    def self.dequeue(table_name:)
      quoted = SQL::Maker::Quoting.quote(table_name)
      queue_timeout_quoted = SQL::Maker::Quoting.quote(Shinq.configuration.queue_timeout)

      wait_query = "queue_wait(#{quoted}, #{queue_timeout_quoted})"
      has_queue = Shinq.connection.query("select #{wait_query}").first

      unless has_queue[wait_query].to_i == 0
        sql = builder.select(table_name, ['*'])
        results = Shinq.connection.query(sql)
        return results.first.symbolize_keys
      end
    end

    def self.done
      Shinq.connection.query('select queue_end()')
    end

    def self.abort
      Shinq.connection.query('select queue_abort()')
    end
  end
end
