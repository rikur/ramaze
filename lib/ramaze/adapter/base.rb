#          Copyright (c) 2008 Michael Fellinger m.fellinger@gmail.com
# All files in this distribution are subject to the terms of the Ruby license.

module Ramaze
  module Adapter

    # (Rack) middleware injected around Adapter::Base::call
    MIDDLEWARE = OrderedSet.new(
      Ramaze::Current,
      Rack::ShowStatus,
      Rack::ShowExceptions
    )

    # Helper to assign a new block to before_call
    # Usage:
    #   Ramaze::Adapter.before do |env|
    #     if env['PATH_INFO'] =~ /suerpfast/
    #       [200, {'Content-Type' => 'text/plain'}, ['super fast!']]
    #     end
    #   end

    def self.before(&block)
      @before = block if block
      @before
    end

    # This class is holding common behaviour for its subclasses.

    class Base
      class << self
        attr_reader :thread

        # For the specified host and for all given ports call run_server and
        # add the returned thread to the Global.adapters ThreadGroup.
        # Afterwards adds a trap for the value of Global.shutdown_trap which
        # calls Ramaze.shutdown when triggered (usually by SIGINT).

        def start(host = nil, port = nil)
          @thread = startup(host, port)
          Global.server = self

          trap(Global.shutdown_trap){
            trap(Global.shutdown_trap){ exit!  }
            exit
          }
        end

        # DEPRECATED: use Adapter::Base::startup instead.

        def start_server(host, port)
          Ramaze::deprecated("Adapter::Base::start_server", "Adapter::Base::startup")
          startup(host, port)
        end

        # Does nothing by default

        def shutdown
          if @server.respond_to?(:stop)
            Log.dev "Stopping @server"
            @server.stop
          else
            Log.dev "Cannot stop @server, skipping this step."
          end
        end

        def join
          @thread.join
        end

        # Tries to find the block assigned by #before and calls it, logs and
        # raises again any errors encountered during this process.

        def before_call env
          if Adapter.before
            begin
              Adapter.before.call(env)
            rescue Object => e
              Ramaze::Log.error e
              raise e
            end
          end
        end

        # This is called by Rack with the usual env, subsequently calls
        # ::respond with it.
        #
        # The method itself acts just as a wrapper for benchmarking and then
        # calls .finish on the current response after ::respond has finished.

        def call(env)
          if returned = before_call(env)
            returned
          elsif Global.benchmarking
            require 'benchmark'
            time = Benchmark.measure{ returned = respond(env) }
            Log.debug('request took %.5fs [~%.0f r/s]' % [time.real, 1.0/time.real])
            returned
          else
            respond(env)
          end
        end

        # Initializes Request with env and an empty Response. Records the
        # request into Ramaze::Record if Global.record is true.
        # Then goes on and calls Dispatcher::handle with request and response.

        def respond(env)
          if Global.server.thread == Thread.current
            Thread.new{ middleware_respond(env) }.value
          else
            middleware_respond(env)
          end
        end

        def middleware_respond(env)
          Thread.current.priority = 1

          if Global.middleware
            MIDDLEWARE.inject{|app, middleware| middleware.new(app) }.call(env)
          else
            Current.call(env)
          end
        end
      end
    end
  end
end
