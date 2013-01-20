PatternDeployer::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = true

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = true

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to nil and saved in location specified by config.assets.prefix
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w(application.js application.css rails_admin/rails_admin.css rails_admin/rails_admin.js backbone-min.js jquery.ba-bbq.min.js swagger-ui.js handlebars-1.0.rc.1.js jquery.slideto.min.js underscore-min.js highlight.7.3.pack.js jquery.wiggle.min.js jquery-1.8.0.min.js swagger.js hightlight.default.css screen.css)

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  # config.active_record.auto_explain_threshold_in_seconds = 0.5



  #####################################################
  #                                                   #
  # custom configurations                             #
  #                                                   #
  #####################################################

  # The location of the chef logs files
  config.chef_logs_dir = Rails.root.join("log")

  # The location of the uploaded files
  config.uploaded_files_dir = "#{Rails.root}/uploaded_files/prod"

  # The location of the uploaded war files
  config.war_files_dir = [config.uploaded_files_dir, "war_files"].join("/")

  # The location of the uploaded identity files
  config.identity_files_dir = [config.uploaded_files_dir, "identity_files"].join("/")

  # The location of the uploaded sql scripts
  config.sql_scripts_dir = [config.uploaded_files_dir, "sql_script_files"].join("/")
end
