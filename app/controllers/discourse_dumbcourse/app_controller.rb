# frozen_string_literal: true

require "rack/mime"

module DiscourseDumbcourse
  class AppController < ::ActionController::Base
    requires_plugin "discourse-dumb-nautas"
    include ::CurrentUser

    layout false
    protect_from_forgery with: :exception
    before_action :ensure_enabled
    before_action :relax_security_headers
    before_action :redirect_anonymous_to_login

    def show
      public_root = DiscourseDumbcourse::Engine.root.join("public")
      request_path = params[:path].to_s
      request_path = request_path.split("?", 2).first.to_s

      format = params[:format].to_s
      if format != "" && request_path != "" && !request_path.end_with?(".#{format}")
        request_path = "#{request_path}.#{format}"
      end

      file_path = self.class.static_file(public_root, request_path)
      if file_path
        ext = file_path.extname.downcase
        mime =
          case ext
          when ".css"
            "text/css; charset=utf-8"
          when ".js"
            "text/javascript; charset=utf-8"
          when ".json"
            "application/json; charset=utf-8"
          else
            Rack::Mime.mime_type(file_path.to_s, "application/octet-stream")
          end
        response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
        return send_data(File.binread(file_path), disposition: "inline", type: mime)
      end

      index_path = public_root.join("index.html")
      unless index_path.file?
        return render plain: "Dumbcourse index missing", status: :internal_server_error
      end

      response.headers["Cache-Control"] = "no-store"
      html = File.read(index_path)
      asset_version =
        (
          begin
            [
              public_root.join("dumbcourse.js").mtime.to_i,
              public_root.join("dumbcourse.css").mtime.to_i,
            ].max
          rescue StandardError
            Time.now.to_i
          end
        )
      html =
        html.gsub(/(dumbcourse\.(?:js|css)\?v=)\d+/) { Regexp.last_match(1) + asset_version.to_s }
      # Mirror any custom-emoji overrides (native Admin → Customize → Emoji
      # uploads AND plugin-registered emoji) into the SPA, so a reaction whose
      # name has a custom image renders that image instead of the native
      # unicode glyph. Auto-syncs with whatever is uploaded; never raises.
      custom_reaction_emojis =
        begin
          ::Emoji
            .custom
            .each_with_object({}) do |e, h|
              url =
                (
                  begin
                    e.url
                  rescue StandardError
                    nil
                  end
                )
              h[e.name] = url if url.present?
            end
        rescue StandardError
          {}
        end

      # The reactions the forum actually has enabled (discourse-reactions), so
      # the SPA's reaction picker matches the main forum instead of a hardcoded
      # list — including any uploaded custom emoji set as reactions.
      enabled_reactions =
        begin
          SiteSetting.discourse_reactions_enabled_reactions.to_s.split("|").reject(&:blank?)
        rescue StandardError
          []
        end

      settings = {
        defaultTheme: SiteSetting.dumbcourse_default_theme,
        defaultView: SiteSetting.dumbcourse_default_view,
        basePath: DiscourseDumbcourse.base_path_with_slash,
        paginationEnabled: SiteSetting.dumbcourse_pagination_enabled,
        topicsPerPage: SiteSetting.dumbcourse_topics_per_page,
        showCategoryNames: SiteSetting.dumbcourse_show_category_names,
        topicPostersVisibility: SiteSetting.dumbcourse_topic_posters_visibility,
        onlineGlowEnabled: SiteSetting.dumbcourse_online_glow_enabled,
        languagetoolEnabled: SiteSetting.dumbcourse_languagetool_enabled,
        leaderboardId: SiteSetting.dumbcourse_leaderboard_id,
        externalLogin: external_login?,
        customEmojis: custom_reaction_emojis,
        enabledReactions: enabled_reactions,
      }
      settings_script =
        "<script nonce=\"#{csp_nonce}\">window.DUMBCOURSE_SETTINGS=#{settings.to_json};</script>"
      if html.include?("</head>")
        html = html.sub("</head>", "#{settings_script}</head>")
      else
        html = settings_script + html
      end

      base_path = DiscourseDumbcourse.base_path_with_slash
      html = html.gsub(%r{"/dumb(?=/|")}, "\"#{base_path}")
      render plain: html, content_type: "text/html; charset=utf-8"
    end

    # Resolves a request path to a regular file strictly inside public_root, or
    # nil. realpath follows symlinks and `..`, so anything escaping the root is
    # rejected no matter how it was spelled.
    def self.static_file(public_root, request_path)
      return nil if request_path.blank? || request_path.include?("\0")
      root = public_root.realpath.to_s
      candidate = File.realpath(File.join(root, request_path))
      return nil unless candidate.start_with?("#{root}/") && File.file?(candidate)
      Pathname.new(candidate)
    rescue SystemCallError
      nil
    end

    private

    def csp_nonce
      @csp_nonce ||= SecureRandom.base64(16)
    end

    def login_path_request?
      path = params[:path]
      path = path.to_s
      path = path.split("?", 2).first.to_s
      if path.empty?
        raw_path = request.path.to_s
        dumb_prefix = "#{Discourse.base_path}#{DiscourseDumbcourse.base_path_with_slash}"
        if raw_path == dumb_prefix
          path = ""
        elsif raw_path.start_with?("#{dumb_prefix}/")
          path = raw_path.sub("#{dumb_prefix}/", "")
        end
      end
      format = params[:format].to_s
      path = "#{path}.#{format}" if format != "" && path != "" && !path.end_with?(".#{format}")
      return true if path == "dumbcourse.css" || path == "dumbcourse.js"
      return true if path&.start_with?("dumbcourse.css") || path&.start_with?("dumbcourse.js")
      return true if path == "login" || path&.start_with?("login/")
      return true if path == "signup" || path&.start_with?("signup/")
      return true if path == "register" || path&.start_with?("register/")
      return true if path == "emoji_map.json"
      false
    end

    def redirect_anonymous_to_login
      return if authenticated?

      if external_login?
        return if asset_request?
        return redirect_to_discourse_login
      end
      return if login_path_request?

      redirect_to "#{Discourse.base_path}#{DiscourseDumbcourse.base_path_with_slash}/login"
    end

    # SSO (DiscourseConnect) or any external provider such as an OIDC
    # Authentik: the app's own password form can't sign anyone in, so login
    # goes through Discourse. Sites with only local logins keep the app form.
    def external_login?
      SiteSetting.enable_discourse_connect || !SiteSetting.enable_local_logins ||
        Discourse.enabled_authenticators.any?
    end

    # Discourse sends the user back to this cookie after DiscourseConnect or
    # OmniAuth, then deletes it, so logins started on the main site are untouched.
    def redirect_to_discourse_login
      cookies[:destination_url] = "#{Discourse.base_path}#{DiscourseDumbcourse.base_path_with_slash}/"
      redirect_to "#{Discourse.base_path}/login"
    end

    def asset_request?
      %w[dumbcourse.css dumbcourse.js emoji_map.json].include?(request.path.split("/").last.to_s)
    end

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.dumbcourse_enabled
    end

    def authenticated?
      current_user.present? || CurrentUser.has_auth_cookie?(request.env)
    end

    # The SPA only needs its own origin for code, and any origin for media
    # (avatars/uploads may live on a CDN). The one inline script is the
    # settings blob, allowed by nonce.
    def relax_security_headers
      response.headers["Content-Security-Policy"] = [
        "default-src 'self'",
        "script-src 'self' 'nonce-#{csp_nonce}'",
        "style-src 'self' 'unsafe-inline'",
        "img-src * data: blob:",
        "media-src * data: blob:",
        "font-src * data:",
        "connect-src 'self' http://localhost:8080 http://127.0.0.1:8080",
        "frame-ancestors 'self'",
        "object-src 'none'",
        "base-uri 'self'",
      ].join("; ")
      response.headers["X-Frame-Options"] = "SAMEORIGIN"
      response.headers["X-Content-Type-Options"] = "nosniff"
      response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    end
  end
end
