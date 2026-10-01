# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dumbcourse, Dumb Nautas additions" do
  fab!(:user)

  before { SiteSetting.dumbcourse_enabled = true }

  def boot_data
    json = response.body[%r{<script type="application/json" id="dc-boot">(.*?)</script>}m, 1]
    JSON.parse(json)
  end

  it "passes the configured leaderboard" do
    SiteSetting.dumbcourse_leaderboard_id = 7
    sign_in(user)
    get "/dumb/"
    expect(boot_data["leaderboardId"]).to eq(7)
  end

  it "signs in locally by default" do
    get "/dumb/login"
    expect(boot_data["auth"]["external"]).to eq(false)
  end

  it "hands sign-in to the full site under DiscourseConnect" do
    SiteSetting.discourse_connect_url = "https://sso.example.com/sso"
    SiteSetting.discourse_connect_secret = "a" * 32
    SiteSetting.enable_discourse_connect = true
    get "/dumb/login"
    expect(boot_data["auth"]["external"]).to eq(true)
  end
end
