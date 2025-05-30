# frozen_string_literal: true

RSpec.describe "gemcutter's dependency API" do
  context "when Gemcutter API takes too long to respond" do
    before do
      require_rack_test

      port = find_unused_port
      @server_uri = "http://127.0.0.1:#{port}"

      require_relative "../../support/artifice/endpoint_timeout"
      require_relative "../../support/silent_logger"

      require "rackup/server"

      @t = Thread.new do
        server = Rackup::Server.start(app: EndpointTimeout,
                                      Host: "0.0.0.0",
                                      Port: port,
                                      server: "webrick",
                                      AccessLog: [],
                                      Logger: Spec::SilentLogger.new)
        server.start
      end
      @t.run

      wait_for_server("127.0.0.1", port)
      bundle "config set timeout 1"
    end

    after do
      Artifice.deactivate
      @t.kill
      @t.join
    end

    it "times out and falls back on the modern index" do
      install_gemfile <<-G, artifice: nil, env: { "BUNDLER_SPEC_GEM_REPO" => gem_repo1.to_s }
        source "#{@server_uri}"
        gem "myrack"
      G

      expect(out).to include("Fetching source index from #{@server_uri}/")
      expect(the_bundle).to include_gems "myrack 1.0.0"
    end
  end
end
