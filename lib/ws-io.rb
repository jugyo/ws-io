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

      Thread.abort_on_exception = true
      m = Mutex.new
      c = ConditionVariable.new

      @server_thread = Thread.start do
        @server = WebSocketServer.new(:accepted_domains => domains, :port => port)
        begin
          @server.run() do |ws|
            if ws.path == "/"
              ws.handshake()
              WsIo.ws = ws
              c.signal                      # ####
              while data = ws.receive()          #
                WsIo.input(data)                 #
              end                                #
            else                                 #  ##     ## ##     ## ######## ######## ##     ## ####
              ws.handshake("404 Not Found")      #  ###   ### ##     ##    ##    ##        ##   ##  ####
            end                                  #  #### #### ##     ##    ##    ##         ## ##   ####
            stop_server                          #  ## ### ## ##     ##    ##    ######      ###     ##
          end                                    #  ##     ## ##     ##    ##    ##         ## ##
        end                                      #  ##     ## ##     ##    ##    ##        ##   ##  ####
      end                                        #  ##     ##  #######     ##    ######## ##     ## ####
                                                 #
      Thread.start do                            #
        m.synchronize { c.wait(m) }         # <###
        @after_block.call if @after_block
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
    end

    def after(&block)
      @after_block = block
      self
    end

    def join
      @server_thread.join if @server_thread
    rescue Exception => e
      g e
    rescue
      unfake_io
      stop_server
    end

    def open
      js_paths = %w(jquery.min.js autoresize.jquery.js).map do |js|
        'file://localhost' + File.expand_path("../public/#{js}", __FILE__)
      end
      template = File.read(File.expand_path('../public/index.html.erb', __FILE__))
      path = Tempfile.open('ws-io') do |tempfile|
        tempfile << ERB.new(template, nil, '-').result(binding)
        tempfile.path
      end
      sleep 0.1
      Launchy::Browser.run(path)
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
      @server.tcp_server.close unless @server.tcp_server.closed?
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
