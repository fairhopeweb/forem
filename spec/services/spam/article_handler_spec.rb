require "rails_helper"

RSpec.describe Spam::ArticleHandler, type: :service do
  describe ".handle!" do
    subject(:handler) { described_class.handle!(article: article) }

    let!(:article) { create(:article) }
    let(:mascot_user) { create(:user) }

    before do
      allow(Settings::General).to receive(:mascot_user_id).and_return(mascot_user.id)
    end

    context "when non-spammy content" do
      before do
        allow(Settings::RateLimit).to receive(:trigger_spam_for?).with(text: article.title).and_return(false)
        allow(Settings::RateLimit).to receive(:trigger_spam_for?).with(text: article.body_markdown).and_return(false)
      end

      it { is_expected.to eq(:not_spam) }
    end

    context "when first time spammy content" do
      before do
        allow(Settings::RateLimit).to receive(:trigger_spam_for?).with(text: article.title).and_return(true)
        allow(Settings::RateLimit).to receive(:trigger_spam_for?).with(text: article.body_markdown).and_return(false)
        allow(Reaction).to receive(:user_has_been_given_too_many_spammy_reactions?)
          .with(user: article.user).and_return(false)
      end

      it "creates a reaction but does not suspend the user" do
        expect { handler }.to change { Reaction.where(reactable: article, category: "vomit").count }.by(1)
        expect(article.user.reload).not_to be_suspended
      end
    end

    context "when multiple offender of spammy" do
      before do
        allow(Settings::RateLimit).to receive(:trigger_spam_for?).with(text: article.title).and_return(true)
        allow(Settings::RateLimit).to receive(:trigger_spam_for?).with(text: article.body_markdown).and_return(false)
        allow(Reaction).to receive(:user_has_been_given_too_many_spammy_reactions?)
          .with(user: article.user).and_return(true)
      end

      it "creates a reaction, suspends the user, and creates a note for the user" do
        expect { handler }.to change { Reaction.where(reactable: article, category: "vomit").count }.by(1)
        expect(article.user.reload).to be_suspended
        expect(Note.where(noteable: article.user, reason: "automatic_suspend").count).to eq(1)
      end
    end
  end
end
