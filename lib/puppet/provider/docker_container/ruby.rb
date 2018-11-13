require 'json'

Puppet::Type.type(:docker_container).provide(:ruby) do
  desc 'Support for Docker Containers'

  mk_resource_methods
  commands docker: 'docker'

  PROPS = {
    name: nil,
    id: nil,
    config: [:labels, :env, :hostname, :domainname, :image],
    state: [:status]
  }

  def self.classify_name(n)
    n.to_s.split('_').map(&:capitalize).join
  end

  def self.port_binding(data)
    data.map do |key, val|
      parts = [ val.first['HostIp'],
                key.split('/').first,
                val.first['HostPort']].reject(&:empty?)
      parts.join(':')
    end
  end

  def self.parse_mounts(data)
    data.map do |mount|
      parts = [ mount['Name'] || mount['Source'],
                mount['Destination']]
      # No options other than 'ro' are documented
      parts << 'ro' unless mount['RW']
      parts.join(':')
    end
  end

  def self.instances
    output = docker(%w[container list --all])
    lines = output.split("\n")
    lines.shift # remove header row
    lines.map do |line|
      id = line.split(' ').first
      inspect = docker(['container', 'inspect', id])
      obj = JSON.parse(inspect).first

      data = PROPS.each_with_object({}) do |(key, subkeys), h|
        subobj = obj[classify_name(key)]
        if subkeys
          subkeys.each do |subkey|
            h[subkey] = subobj[classify_name(subkey)]
          end
        else
          h[key] = subobj
        end
      end

      data[:port_bindings] = port_binding(obj["HostConfig"]["PortBindings"])

      data[:volumes] = parse_mounts(obj["Mounts"])


      data[:networks] = obj["NetworkSettings"]["Networks"].keys

      # how do we differentiate between running and non-running
      data[:ensure] = :present


      new(data)
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if (resource = resources[prov.name])
        resource.provider = prov
      end
    end
  end

  def initialize(*args)
    super(*args)
    @original_props = @property_hash.dup
  end

  def exists?
    Puppet.info("Checking if docker Container #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating docker container#{name}")

    options = ['--name', resource[:name]]

    if (labels = resource[:labels])
      labels.each { |label, val| options << '--label' << "#{label}=#{val}" }
    end

    if (env = resource[:env])
      env.each { |val| options << '--env' << val }
    end

    if (bindings = resource[:port_bindings])
      bindings.each { |val| options << '--publish' << val }
    end

    if nets = resource[:networks]
      # TODO support more than one network
      options << '--network' << nets.first
    end

    if (vols = resource[:volumes])
      vols.each { |val| options << '--volume' << val }
    end

    args = %w[container run] + options << resource[:image]
    docker(args)
  end

  def flush(*args)
    # Any changes require recreating the container for now
    destroy
    create
  end

  def destroy
    Puppet.info("Removing docker container #{name}")
    docker(['container', 'rm', '-f', name])
  end

  # TODO: this is less useful now that we're not using the ID
  def image_insync(should, is)
    return true if should == is

    begin
      should_data = JSON.parse(docker(%W[image inspect #{should}])).first
    rescue
      docker(%W[image pull #{should}])
      should_data = JSON.parse(docker(%W[image inspect #{should}])).first
    end

    is_data = JSON.parse(docker(%W[image inspect #{is}])).first

    # TODO: This should be more flexible with repos and tags.
    return should_data["Id"] == is_data["Id"]
  end

  def container_data
    @container_data ||= JSON.parse(docker(%W[container inspect #{@property_hash[:id]}])).first
  end

  def image_data
    @image ||= JSON.parse(docker(%W[image inspect #{container_data["Image"]}])).first
  end

  def env_insync(should, is)
    image_env = image_data['Config']['Env']
    # Should this happen during discovery?
    is = is.reject {|e| image_env.include?(e) }
    is.sort == should.sort
  end
end
