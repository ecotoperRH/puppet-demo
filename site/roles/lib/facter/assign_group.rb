Facter.add('server_group') do
  setcode do
    fqdn = Facter.value(:fqdn)
    if fqdn && fqdn.match?(/^consul-0\d+\.srv\.local$/)
      'consul-server'
    else
      nil
    end
  end
end
