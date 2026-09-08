require "rails_helper"

RSpec.describe "Favicon", type: :request do
  it "links to the app icon and no longer references the removed placeholder SVG" do
    get root_path

    expect(response.body).to include('<link rel="icon" href="/icon.png" type="image/png">')
    expect(response.body).not_to include("icon.svg")
  end
end
