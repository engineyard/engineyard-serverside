require 'yaml'
unit = ARGV.shift
hash = YAML.load_file('build_units.yml')
assignment = hash[unit]
puts assignment
