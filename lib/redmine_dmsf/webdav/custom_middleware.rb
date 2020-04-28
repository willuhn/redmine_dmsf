# encoding: utf-8
# frozen_string_literal: true
#
# Redmine plugin for Document Management System "Features"
#
# Copyright © 2011-20 Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'dav4rack'

module RedmineDmsf
  module Webdav

    class CustomMiddleware

      def initialize(app)
        @rails_app = app
        path = File.join(Redmine::Utils::relative_url_root, %w(dmsf webdav))
        @dav_app = Rack::Builder.new{
          map '/dmsf/webdav/' do
            run DAV4Rack::Handler.new(
              root_uri_path: path,
              resource_class: RedmineDmsf::Webdav::ResourceProxy,
              log_to: Rails.logger,
              allow_unauthenticated_options_on_root: true,
              namespaces: {
                'http://apache.org/dav/props/' => 'd',
                'http://ucb.openoffice.org/dav/props/' => 'd'
              }
            )
          end
        }.to_app
      end

      def call(env)
        begin
          status, headers, body = @dav_app.call env
        rescue Exception => e
          Rails.logger.error e.message
          status = e
          headers = {}
          body = ['']
        end
        # If the URL map generated by Rack::Builder did not find a matching path,
        # it will return a 404 along with the X-Cascade header set to 'pass'.
        if (status == 404) && (headers['X-Cascade'] == 'pass')
          # The MS web redirector webdav client likes to go up a level and try
          # OPTIONS and PROPFIND there. We catch that here and respond telling it that just
          # plain HTTP is going on.
          if %w(/ /dmsf).include?(env['PATH_INFO'])
            if 'OPTIONS'.casecmp(env['REQUEST_METHOD']) == 0
              [ '200', { 'Allow' => 'OPTIONS,HEAD,GET,PUT,POST,DELETE' }, [''] ]
            elsif 'PROPFIND'.casecmp(env['REQUEST_METHOD']) == 0
              [ '404', {}, [''] ]
            else
              @rails_app.call env # let Rails handle the request
            end
          else
            @rails_app.call env # let Rails handle the request
          end
        else
          [status, headers, body]
        end
      end

    end

  end
end