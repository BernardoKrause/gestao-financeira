# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# NOTE: vendor/javascript/chart.js.js is NOT the file `bin/importmap pin chart.js`
# downloads by default -- that ESM build has an internal relative import to a
# jspm-split shared chunk that importmap-rails' vendoring step never fetches,
# so it 404s in the browser. It has been manually replaced with Chart.js's
# self-contained UMD build (see the header comment in that file for details).
# Re-running `bin/importmap pin chart.js` will silently reintroduce the broken
# file -- if you do, re-vendor the UMD build instead.
pin "chart.js", preload: false # @4.5.1
pin "sortablejs", preload: false # @1.15.7
