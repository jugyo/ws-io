require 'erb'
require 'thread'
require 'tempfile'
require 'web_socket'
require "launchy"

class WsIo
  class << self
    attr_accessor :ws, :domains, :port

    if ENV['WSIO_DEBUG']
      require 'g'
    else
      def g(*args);end
    end

    def start(port = 8080, domains = ["*"])
      @port = port
      @domains = domains

      fake_io

      m = Mutex.new
      c = ConditionVariable.new

      @server_thread = Thread.start do
        @server = WebSocketServer.new(:accepted_domains => domains, :port => port)
        begin
          @server.run() do |ws|
            if ws.path == "/"
              ws.handshake()
              WsIo.ws = ws
              ws.send("connected")
              c.signal                      # ####
              while data = ws.receive()          #
                WsIo.input(data)                 #
              end                                #
            else                                 #  ##     ## ##     ## ######## ######## ##     ## ####
              ws.handshake("404 Not Found")      #  ###   ### ##     ##    ##    ##        ##   ##  ####
            end                                  #  #### #### ##     ##    ##    ##         ## ##   ####
            stop_server                          #  ## ### ## ##     ##    ##    ######      ###     ##
          end                                    #  ##     ## ##     ##    ##    ##         ## ##
        rescue => e                              #  ##     ## ##     ##    ##    ##        ##   ##  ####
          g e                                    #  ##     ##  #######     ##    ######## ##     ## ####
        end                                      #
      end                                        #
                                                 #
      Thread.start do                            #
        m.synchronize { c.wait(m) }         # <###
        loop do
          if @ws
            begin
              @ws.send(escape(output))
            rescue
              # ignore!
            end
          end
        end
      end

      Thread.start do
        begin
          yield
        rescue => e
          g e
        ensure
          unfake_io
          stop_server
        end
      end

      self
    rescue SignalException, StandardError => e
      g e
      unfake_io
      stop_server
      raise
    rescue Exception => e
      g e
      unfake_io
      stop_server
      raise
    end

    def after
      yield
      self
    end

    def join
      @server_thread.join if @server_thread
    end

    def open
      tempfile = Tempfile.open('ws-io')
      tempfile << ERB.new(File.read(File.expand_path('../index.html.erb', __FILE__))).result(binding)
      tempfile.flush
      Launchy::Browser.run(tempfile.path)
      self
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
      [@in_read, @in_write, @out_read, @out_write].each do |io|
        io.close unless io.closed?
      end
      g 'unfake_io'
    rescue => e
      g e
    end

    def stop_server
      ws.close
      @server.tcp_server.close
      g 'stop_server'
    rescue => e
      g e
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
