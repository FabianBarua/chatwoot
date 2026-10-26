json.id resource.id
json.csat_survey_response resource.csat_survey_response
json.display_type resource.inbox.csat_config.try(:[], 'display_type') || 'emoji'
json.content resource.inbox.csat_config.try(:[], 'message')
# Xplus: reasons offered after a low rating; nil means the survey uses its default list
json.reasons resource.inbox.csat_config.try(:[], 'reasons')
json.reasons_max_rating resource.inbox.csat_config.try(:[], 'reasons_max_rating') || Inbox::CSAT_REASONS_MAX_RATING
json.inbox_avatar_url resource.inbox.avatar_url
json.inbox_name resource.inbox.name
json.locale resource.account.locale
json.conversation_id resource.conversation_id
json.created_at resource.created_at
