# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Category checklist in the composer" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category, title: "A topic in a scoped category") }
  fab!(:op) { Fabricate(:post, topic: topic, raw: "The original post in this thread.") }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.min_post_length = 5
    SiteSetting.body_min_entropy = 1
    category.custom_fields[NautasCategoryChecklist::FIELD] = {
      "items" => [{ "label" => "I read the category rules", "url" => "" }],
      "button_label" => "Accept and post",
      "max_tl" => 4,
      "version" => 1,
    }
    category.save_custom_fields(true)
  end

  def reply(text)
    find("#topic-footer-buttons .create", match: :first).click
    find(".d-editor-input").fill_in(with: text)
    find(".save-or-cancel .create").click
  end

  it "asks once, then lets the person post freely" do
    sign_in(user)
    visit(topic.url)

    reply("Here is my first reply in this category.")
    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    expect(page).to have_css(".mod-checklist-confirm[disabled]")
    all(".mod-checklist-item-label").each(&:click)
    find(".mod-checklist-confirm").click
    expect(page).to have_css(".topic-post", minimum: 2, wait: 10)

    reply("And a second reply, with no checklist this time.")
    expect(page).to have_css(".topic-post", minimum: 3, wait: 10)
    expect(page).to have_no_css(".mod-first-post-checklist-modal")
  end
end
