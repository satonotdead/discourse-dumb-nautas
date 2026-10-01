# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Category checklist" do
  fab!(:moderator)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:op) { Fabricate(:post, topic: topic) }
  fab!(:other_topic) { Fabricate(:topic, category: other_category) }
  fab!(:other_op) { Fabricate(:post, topic: other_topic) }

  let(:items) { [{ label: "I read the rules", url: "https://example.com/rules" }] }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.min_post_length = 5
    SiteSetting.body_min_entropy = 1
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    SiteSetting.approve_unless_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
  end

  def set_checklist(params = {})
    sign_in(moderator)
    put "/nautas/category-checklist/#{category.id}.json", params: { items: items }.merge(params)
    expect(response.status).to eq(200)
  end

  def reply_in(t)
    post "/posts.json", params: { topic_id: t.id, raw: "A reply long enough to be valid here." }
  end

  def new_topic_in(c)
    post "/posts.json",
         params: {
           category: c.id,
           title: "A brand new topic in this category",
           raw: "The body of a brand new topic in here.",
         }
  end

  def accept(version = 1)
    post "/discourse-mod-categories/checklist/accept.json",
         params: {
           kind: "category",
           id: category.id,
           version: version,
         }
  end

  describe "setting it up" do
    it "lets staff save, read and remove it" do
      set_checklist(button_label: "I agree")
      expect(response.parsed_body["version"]).to eq(1)

      get "/nautas/category-checklist/#{category.id}.json"
      expect(response.parsed_body["items"]).to eq([items.first.stringify_keys])
      expect(response.parsed_body["button_label"]).to eq("I agree")

      delete "/nautas/category-checklist/#{category.id}.json"
      expect(response.status).to eq(200)
      expect(NautasCategoryChecklist.config(category.reload)).to be_nil
    end

    it "keeps the version on a plain save and bumps it when asked to re-ask" do
      set_checklist
      set_checklist
      expect(response.parsed_body["version"]).to eq(1)
      set_checklist(reask: true)
      expect(response.parsed_body["version"]).to eq(2)
    end

    it "drops unsafe links" do
      set_checklist(items: [{ label: "Click", url: "javascript:alert(1)" }])
      expect(response.parsed_body["items"]).to eq([{ "label" => "Click", "url" => "" }])
    end

    it "is staff only" do
      sign_in(user)
      put "/nautas/category-checklist/#{category.id}.json", params: { items: items }
      expect(response.status).to eq(403)
      get "/nautas/category-checklist/#{category.id}.json"
      expect(response.status).to eq(403)
    end
  end

  describe "posting" do
    before { set_checklist }

    it "blocks replies and new topics in the category until accepted, once" do
      sign_in(user)

      reply_in(topic)
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"].join).to include(category.name)

      new_topic_in(category)
      expect(response.status).to eq(422)

      get "/nautas/category-checklist/owed.json", params: { topic_id: topic.id }
      expect(response.parsed_body["checklist"]["kind"]).to eq("category")

      accept
      expect(response.status).to eq(200)

      get "/nautas/category-checklist/owed.json", params: { category_id: category.id }
      expect(response.parsed_body["checklist"]).to be_nil

      reply_in(topic)
      expect(response.status).to eq(200)
      new_topic_in(category)
      expect(response.status).to eq(200)
    end

    it "leaves other categories alone" do
      sign_in(user)
      reply_in(other_topic)
      expect(response.status).to eq(200)
    end

    it "asks again after staff re-ask" do
      sign_in(user)
      accept
      set_checklist(reask: true)

      sign_in(user)
      reply_in(topic)
      expect(response.status).to eq(422)
      accept(2)
      reply_in(topic)
      expect(response.status).to eq(200)
    end

    it "never asks staff" do
      reply_in(topic)
      expect(response.status).to eq(200)
    end

    it "skips trust levels above the cap" do
      set_checklist(max_tl: 0)
      sign_in(user)
      reply_in(topic)
      expect(response.status).to eq(200)
    end

    it "does nothing when switched off" do
      SiteSetting.nautas_category_checklist_enabled = false
      sign_in(user)
      reply_in(topic)
      expect(response.status).to eq(200)
    end
  end
end
