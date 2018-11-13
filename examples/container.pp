
docker_container{ '/my_cont':
  image => 'ubuntu:trusty',
  env => ["FOO=bar", "baz=fuck"],
  networks => ["foo", 'bar'],
  volumes => ['/tmp:/foo'],
  labels => { 'bz' => 'qux' }

}
