# encoding: utf-8
module Rails31
  class Application < Rails::Application
    config.assets.enabled = false
    # ☃  漢字仮名交じり文
  end
end
