#!/usr/bin/env ruby
$:.unshift File.dirname(__FILE__) + "/../lib"
require "ws-io"

threads = []
threads << Thread.start do
  WsIo.start(['*'], 8080) do
    system '/bin/sh'
  end
end
threads << Thread.start do
  system 'open', File.expand_path('../index.html', __FILE__)
end
threads.each { |thread| thread.join }
