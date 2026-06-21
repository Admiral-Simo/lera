class Rack::Attack
  # 1. Enable Rack::Attack in development environment if needed
  # Rails.env.development? ? true : false

  # 2. Use ActiveSupport::Cache::MemoryStore or Redis for tracking rates
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Throttle Passport Scanning Endpoint ###
  # Allow 2 requests per minute per User (or IP if unauthenticated)
  throttle("passports/create", limit: 2, period: 1.minute) do |req|
    if req.path == "/passports" && req.post?
      # 1. Look for the raw signed session cookie string directly from the Rack env headers
      cookie_header = req.env["HTTP_COOKIE"]

      if cookie_header
        # 2. Extract the 'session_id' value using a regular expression regex match
        match = cookie_header.match(/session_id=([^;]+)/)
        session_id = match[1] if match
      end

      # 3. Fall back gracefully to the standard IP address if no session cookie exists yet
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
