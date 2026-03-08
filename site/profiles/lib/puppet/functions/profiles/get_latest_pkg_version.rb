require 'net/http'
require 'json'

Puppet::Functions.create_function(:'profiles::get_latest_pkg_version') do
  dispatch :get_latest_pkg_version do
    param 'String', :api_url
    optional_param 'Integer', :limit
    return_type 'String'
  end

  def get_latest_pkg_version(api_url, limit = 3)
    # Raise Error if the request has more than 3 redirections (rare case)
    raise Puppet::Error, 'Too many redirects' if limit <= 0

    uri = URI(api_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')

    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Puppet'

    response = http.request(request)

    case response
    when Net::HTTPSuccess
      data = JSON.parse(response.body)

      tag =
        data['tag_name'] ||          # GitHub & GitLab
        data.dig('release', 'tag')   # fallback

      raise Puppet::Error, "tag_name missing in #{data}" unless tag

      tag.sub(/^v/, '')
    
    # Handle GitLab API's redirection for the latest release
    when Net::HTTPRedirection
      location = response['location']
      new_uri = URI.join(uri, location)

      get_latest_pkg_version(new_uri.to_s, limit - 1)

    else
      raise Puppet::Error,
            "HTTP #{response.code} fetching #{api_url}: #{response.body}"
    end
  end
end
