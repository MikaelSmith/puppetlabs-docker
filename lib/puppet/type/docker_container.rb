Puppet::Type.newtype(:docker_container) do
  @doc = 'A type representing a docker container'
  ensurable

  newparam(:name) do
    isnamevar
    desc 'The name of the container'
    validate do |value|
      unless value.start_with?('/')
        raise(Puppet::ParseError, "Container names must start with '/'")
      end
    end
  end

  # These are from the 1.37 api docs but don't match what I get with 18.06
  newproperty(:id,  :readonly => true)

  newproperty(:image) do
    desc "The image the container should be built from"

    def insync?(is)
      provider.image_insync(@should.first, is)
    end
  end

  newproperty(:status)
  newproperty(:hostname)
  newproperty(:domainname)

  # TODO implement labels
  newproperty(:labels) do
  end

  newproperty(:env, array_matching: :all) do
    def insync?(is)
      provider.env_insync(@should, is)
    end
  end

  newproperty(:port_bindings, array_matching: :all) do
    def insync?(is)
      is.sort == @should.sort
    end
  end

  newproperty(:networks, array_matching: :all) do
    def insync?(is)
      is.sort == @should.sort
    end
  end

  # This uses the "volume syntax" because it's easier to parse
  newproperty(:volumes, array_matching: :all) do
    def insync?(is)
      is.sort == @should.sort
    end
  end
end
