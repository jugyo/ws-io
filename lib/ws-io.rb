require 'web_socket'
require 'erb'

class WsIo
  class << self
    attr_accessor :ws

    if ENV['WSIO_DEBUG']
      require 'g'
    else
      def g(*args);end
    end

    def start(domains = ["*"], port = 8080)
      fake_io

      threads = []

      threads << Thread.start do
        @server = WebSocketServer.new(:accepted_domains => domains, :port => port)
        @server.run() do |ws|
          if ws.path == "/"
            ws.handshake()
            WsIo.ws = ws
            while data = ws.receive()
              WsIo.input(data)
            end
          else
            ws.handshake("404 Not Found")
          end
          stop_server
        end
      end

      threads << Thread.start do
        begin
          yield
        ensure
          stop_server
        end
      end

      threads << Thread.start do
        loop do
          break if @ws && @ws.instance_variable_get(:@socket).closed?
          if @ws
            begin
              @ws.send(escape(output))
            rescue
              # ignore!
            end
          end
        end
      end

      threads.each do |thread|
        thread.join
      end
    rescue SignalException, StandardError
      unfake_io
    rescue Exception
      unfake_io
      raise
    end

    def fake_io
      @in_read, @in_write = IO.pipe
      @stdin = STDIN.clone
      STDIN.reopen(@in_read)
      @stdout = STDOUT.clone
      @stderr = STDERR.clone
      @out_read, @out_write = IO.pipe
      STDOUT.reopen(@out_write)
      STDERR.reopen(@out_write)
      g 'fake_io'
    end

    def unfake_io
      STDIN.reopen(@stdin)
      STDOUT.reopen(@stdout)
      STDERR.reopen(@stderr)
      @in_read.close
      @in_write.close
      @out_write.close
      @out_read.close
      g 'unfake_io'
    end

    def stop_server
      ws.close
      @server.tcp_server.close
      g 'stop_server'
    end

    def stop
      stop_server
      unfake_io
    end

    def input(msg)
      @in_write.puts(msg + "\n")
    end

    def output
      @out_read.gets
    end

    def escape(output)
      ERB::Util.html_escape(output.gsub(/\e\[[^m]+m/, '')) if output
    end
  end
end
