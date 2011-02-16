#!/usr/bin/env ruby
$:.unshift File.dirname(__FILE__) + "/../lib"
require "ws-io"

WsIo.start(8080) {
  system '/bin/sh'
}.join
