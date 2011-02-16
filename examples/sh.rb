#!/usr/bin/env ruby
$:.unshift File.dirname(__FILE__) + "/../lib"

require "ws-io"

WsIo.start {
  system '/bin/sh'
}.open.join
