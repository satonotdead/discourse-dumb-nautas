# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSmartSearch::Synonyms do
  before { described_class.reload! }

  it "finds Spanish synonyms, ignoring accents, for Spanish requests" do
    I18n.with_locale(:es) do
      expect(described_class.for("canción")).to include("canto")
      expect(described_class.for("cancion")).to include("canción", "canto")
    end
  end

  it "never uses the Spanish dictionary for English requests" do
    I18n.with_locale(:en) { expect(described_class.for("canción")).to eq(["canción"]) }
  end

  it "does not expand Spanish stop words" do
    I18n.with_locale(:es) do
      expect(DiscourseSmartSearch::QueryExpander.variants("de la")).to eq([])
    end
  end
end
