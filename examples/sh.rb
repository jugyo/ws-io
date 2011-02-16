#!/usr/bin/env ruby
$:.unshift File.dirname(__FILE__) + "/../lib"
require "ws-io"
require "launchy"

Launchy::Browser.run(File.expand_path('../index.html', __FILE__))

WsIo.start(['*'], 8080) {
  system '/bin/sh'
}.join
