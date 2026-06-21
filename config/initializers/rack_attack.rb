class Rack::Attack
  # 1. Enable Rack::Attack in development environment if needed
  # Rails.env.development? ? true : false

  # 2. Use ActiveSupport::Cache::MemoryStore or Redis for tracking rates
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Throttle Passport Scanning Endpoint ###
  # Allow 5 requests per minute per User (or IP if unauthenticated)
  throttle("passports/create", limit: 5, period: 1.minute) do |req|
    if req.path == "/passports" && req.post?
      # Try to identify user via session cookie if available, otherwise fall back to IP
      # Note: Adjust cookie key name based on your Rails 8 configuration
      cookies = ActionDispatch::Cookies::CookieJar.build(req, req.cookies)
      session_id = cookies.signed[:session_id]

      session_id ? "user_session_#{session_id}" : req.ip
    end
  end

  ### Custom Response on Throttle ###
  self.throttled_responder = lambda do |request|
    [ 429,  # Status Code: Too Many Requests
      { "Content-Type" => "application/json" },
      [{ error: "Rate limit exceeded. Please wait before scanning another passport." }.to_json]
    ]
  end
end
