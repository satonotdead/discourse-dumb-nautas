# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dumbcourse app shell" do
  fab!(:user)

  before do
    SiteSetting.dumbcourse_enabled = true
    sign_in(user)
  end

  it "serves its own assets" do
    get "/dumb/dumbcourse.js"
    expect(response.status).to eq(200)
    expect(response.media_type).to eq("text/javascript")
  end

  it "never serves files outside its public folder" do
    %w[../plugin.rb ..%2Fplugin.rb ../../../../../../etc/passwd].each do |path|
      get "/dumb/#{path}"
      expect(response.body).not_to include("frozen_string_literal")
      expect(response.body).not_to include("root:")
    end
  end

  it "sends a restrictive security policy" do
    get "/dumb/"
    expect(response.status).to eq(200)
    csp = response.headers["Content-Security-Policy"]
    expect(csp).to include("frame-ancestors 'self'")
    expect(csp).not_to include("unsafe-eval")
    nonce = csp[/'nonce-([^']+)'/, 1]
    expect(response.body).to include(%(<script nonce="#{nonce}">window.DUMBCOURSE_SETTINGS=))
    expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
    expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
  end

  it "exposes the leaderboard id to the SPA" do
    SiteSetting.dumbcourse_leaderboard_id = 6
    get "/dumb/"
    expect(response.body).to include(%("leaderboardId":6))
  end

  describe "CSRF" do
    around do |example|
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "rejects a forged push registration" do
      SiteSetting.dumbcourse_push_enabled = true
      post "/dumb/push/register.json", params: { topic: "evil", device_id: "d" }
      expect(response.status).to eq(403)
      expect(PluginStore.get("dumbcourse", "push_devices_#{user.id}")).to be_nil
    end
  end
end

RSpec.describe "Dumbcourse login with SSO" do
  before do
    SiteSetting.dumbcourse_enabled = true
    SiteSetting.discourse_connect_url = "https://idp.example.com/sso"
    SiteSetting.discourse_connect_secret = "a" * 32
    SiteSetting.enable_discourse_connect = true
  end

  it "sends anonymous visitors to Discourse login and back to the app" do
    get "/dumb/latest"
    expect(response).to redirect_to("/login")
    expect(cookies[:destination_url]).to eq("/dumb/")
  end

  it "still serves the app's assets" do
    get "/dumb/dumbcourse.js"
    expect(response.status).to eq(200)
  end
end
