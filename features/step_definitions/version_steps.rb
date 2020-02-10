require 'engineyard-serverside/version'

Then %{the current version is displayed} do
  expect(output_text).to include(EY::Serverside::VERSION)
end
