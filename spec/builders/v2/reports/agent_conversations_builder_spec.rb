require 'rails_helper'

RSpec.describe V2::Reports::AgentConversationsBuilder do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, name: 'WhatsApp') }
  let(:params) { { since: 3.days.ago.beginning_of_day.to_i.to_s, until: Time.current.end_of_day.to_i.to_s } }

  let(:rated_low) { create(:conversation, account: account, inbox: inbox, assignee: agent, status: :resolved) }
  let(:rated_high) { create(:conversation, account: account, inbox: inbox, assignee: agent, status: :resolved) }
  let(:not_rated) { create(:conversation, account: account, inbox: inbox, assignee: agent, status: :resolved) }

  before do
    create(:reporting_event, account: account, inbox: inbox, conversation: rated_low, user: agent, name: 'conversation_resolved',
                             created_at: 2.days.ago)
    create(:reporting_event, account: account, inbox: inbox, conversation: rated_high, user: agent, name: 'conversation_resolved',
                             created_at: 1.day.ago)
    create(:reporting_event, account: account, inbox: inbox, conversation: not_rated, user: agent, name: 'conversation_resolved',
                             created_at: 1.hour.ago)
    create(:csat_survey_response, account: account, conversation: rated_low, assigned_agent: agent, rating: 1, reason: 'Demora en responder')
    create(:csat_survey_response, account: account, conversation: rated_high, assigned_agent: agent, rating: 5, reason: nil)

    # Resolved by someone else and outside the period: never listed
    other = create(:conversation, account: account, inbox: inbox, assignee: other_agent, status: :resolved)
    create(:reporting_event, account: account, inbox: inbox, conversation: other, user: other_agent, name: 'conversation_resolved')
    old = create(:conversation, account: account, inbox: inbox, assignee: agent, status: :resolved)
    create(:reporting_event, account: account, inbox: inbox, conversation: old, user: agent, name: 'conversation_resolved', created_at: 10.days.ago)
  end

  def build(extra = {})
    described_class.new(account: account, user: agent, params: params.merge(extra)).build
  end

  it 'lists the conversations the agent resolved in the period, latest first, with their CSAT' do
    result = build

    expect(result[:total_count]).to eq(3)
    expect(result[:records].map { |row| row[:display_id] }).to eq([not_rated, rated_high, rated_low].map(&:display_id))
    expect(result[:records].first[:csat]).to be_nil
    expect(result[:records].last[:csat]).to include(rating: 1, reason: 'Demora en responder')
    expect(result[:records].last[:inbox]).to eq({ id: inbox.id, name: 'WhatsApp' })
  end

  it 'filters by rating, including the ones without a rating' do
    expect(build(rating: '1')[:records].map { |row| row[:display_id] }).to eq([rated_low.display_id])
    expect(build(rating: 'none')[:records].map { |row| row[:display_id] }).to eq([not_rated.display_id])
  end

  it 'filters by reason, including the rated ones without a reason' do
    expect(build(reason: 'Demora en responder')[:records].map { |row| row[:display_id] }).to eq([rated_low.display_id])
    expect(build(reason: 'none')[:records].map { |row| row[:display_id] }).to eq([rated_high.display_id])
  end

  it 'paginates' do
    stub_const('V2::Reports::AgentConversationsBuilder::PER_PAGE', 2)

    expect(build(page: '1')[:records].size).to eq(2)
    expect(build(page: '2')[:records].map { |row| row[:display_id] }).to eq([rated_low.display_id])
    expect(build(page: '2')[:total_count]).to eq(3)
  end
end
