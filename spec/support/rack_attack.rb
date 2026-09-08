RSpec.configure do |config|
  config.around(:example, rack_attack: true) do |example|
    original_store = Rack::Attack.cache.store
    original_enabled = Rack::Attack.enabled

    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true

    example.run

    Rack::Attack.cache.store = original_store
    Rack::Attack.enabled = original_enabled
  end
end
