class Agents::AvailabilitySnapshotJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Account.find_each(batch_size: 100) do |account|
      Agents::AvailabilityLogService.new(account: account).snapshot
    end
  end
end
