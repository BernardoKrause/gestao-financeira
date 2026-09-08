require "rails_helper"

RSpec.describe "Favicon", type: :request do
  [
    [ "the public layout", -> { root_path } ],
    [ "the auth layout", -> { new_user_session_path } ]
  ].each do |layout_name, path_proc|
    it "links to the app icon and no longer references the removed placeholder SVG on #{layout_name}" do
      get instance_exec(&path_proc)

      expect(response.body).to include('<link rel="icon" href="/icon.png" type="image/png">')
      expect(response.body).not_to include("icon.svg")
    end
  end
end
