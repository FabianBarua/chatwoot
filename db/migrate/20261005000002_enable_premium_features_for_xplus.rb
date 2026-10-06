# Xplus edition: all Enterprise (premium) features are available, so they are switched on for
# every existing account and in the defaults used for new accounts. Cloud-internal flags
# (advanced_search_indexing, help_center_embedding_search, captain_v1_action_classifier) stay off.
class EnablePremiumFeaturesForXplus < ActiveRecord::Migration[7.1]
  PREMIUM_FEATURES = %w[
    disable_branding audit_logs custom_tools sla captain_integration custom_roles channel_voice
    captain_integration_v2 captain_document_auto_sync saml companies csat_review_notes
    conversation_required_attributes advanced_assignment audit_log_ip_address advanced_search
  ].freeze

  def up
    set_config('INSTALLATION_PRICING_PLAN', 'enterprise')
    set_config('INSTALLATION_PRICING_PLAN_QUANTITY', 10_000)
    enable_in_defaults
    enable_in_accounts
    GlobalConfig.clear_cache
  end

  private

  def set_config(name, value)
    config = InstallationConfig.find_or_initialize_by(name: name)
    config.value = value
    config.locked = true
    config.save!
  end

  def enable_in_defaults
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return if config.blank? || config.value.blank?

    config.value = config.value.map do |feature|
      PREMIUM_FEATURES.include?(feature['name']) ? feature.merge('enabled' => true) : feature
    end
    config.save!
  end

  def enable_in_accounts
    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each { |account| account.enable_features!(*PREMIUM_FEATURES) }
    end
  end
end
