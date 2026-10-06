require 'rails_helper'

RSpec.describe AutoAssignmentHandler do
  describe 'assignment v2 trigger' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }

    before do
      account.enable_features!('assignment_v2')
      allow(AutoAssignment::AssignmentJob).to receive(:enqueue_for_inbox)
    end

    it 'enqueues the inbox assignment job only once the new conversation is committed' do
      ActiveRecord::Base.transaction do
        create(:conversation, account: account, inbox: inbox, assignee: nil)
        # The job scans committed unassigned conversations, so it must not run before the commit
        expect(AutoAssignment::AssignmentJob).not_to have_received(:enqueue_for_inbox)
      end

      expect(AutoAssignment::AssignmentJob).to have_received(:enqueue_for_inbox).with(inbox.id)
    end

    it 'does not enqueue the job when the surrounding transaction rolls back' do
      ActiveRecord::Base.transaction do
        create(:conversation, account: account, inbox: inbox, assignee: nil)
        raise ActiveRecord::Rollback
      end

      expect(AutoAssignment::AssignmentJob).not_to have_received(:enqueue_for_inbox)
    end
  end
end
