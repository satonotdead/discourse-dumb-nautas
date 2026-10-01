# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Power Tools Nautas whisper glue" do
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:target, :user)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, user: author) }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    SiteSetting.min_post_length = 5
    SiteSetting.body_min_entropy = 1
    SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
  end

  it "keeps a mod whisper regular even when the composer also sent a core whisper flag" do
    sign_in(moderator)
    post "/posts.json",
         params: {
           :topic_id => topic.id,
           :raw => "This is a whisper reply body long enough to be valid.",
           DiscourseModCategories::POST_WHISPER_ARMED_PARAM => true,
           DiscourseModCategories::POST_WHISPER_TARGETS_FIELD => [target.id],
           :whisper => true,
         }
    expect(response.status).to eq(200)

    created = Post.find(response.parsed_body["id"])
    expect(created.post_type).to eq(Post.types[:regular])
    expect(Guardian.new(target).can_see_post?(created)).to eq(true)
  end
end
