# Avo's engine appends its own config/importmap.rb (`pin "avo/application"`,
# preload: true by default) to the host app's importmap. That makes every
# public page — not just /admin — emit a <link rel="modulepreload"> for Avo's
# ~3.1 MB admin JS bundle, which anonymous visitors would eagerly download.
#
# Avo's own /admin layout loads its JS via `javascript_include_tag
# "avo/application"`, not through the importmap, so disabling the preload
# here does not affect /admin at all.
Rails.application.config.after_initialize do
  Rails.application.importmap.pin "avo/application", preload: false
end
