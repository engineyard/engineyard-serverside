namespace :partitioner do

  # behold the amazingness! this task analyzes all specs and distributes them evenly
  # over the optimal amount of build units. (optimal amount is: the most expensive
  # task (time-wise) is alone in a unit and the other tasks don't exceed this time in total.)
  #
  # best thing to do is: run this task over night on the pairing machines or run it anywhere
  # in the ec2 world
  #
  # if you just checked in a new file look add the quick_add task
  desc "rebalance all specs over the workers, aye"
  task :balance do
    require 'yaml'
    require 'partitioner'
    require 'open4'

    type_specs = Dir.glob("spec/**/*_spec.rb")

    i = 0
    @timings = type_specs.map do |spec|
      i += 1
      puts "Processing #{i} of #{type_specs.size} - #{spec}"
      start = Time.now
      Open4::popen4 "bundle exec spec #{spec}" do |pid, stdin, stdout, stderr|
        stdin.close
        err = stderr.read.strip
        puts err unless err
      end
      [spec , Time.now - start]
    end

    puts "Calculating buckets for ..."
    partitioner = Partitioner.new
    partitioner.kb = @timings

    # adding build units into the ci.yml
    puts "writing ci.yml"
    ci = (File.exist?('ci.yml') ? YAML.load_file('ci.yml') : {}) || {}
    ci['units'] ||= []
    ci["units"].delete_if {|unit| unit =~ /specs-\d+$/}
    partitioner.buckets.size.times do |i|        # adds the modellines
      ci["units"] << "specs-#{i+1}"
    end
    File.open("ci.yml","w") do |f|
      YAML.dump(ci, f)
    end

    # adding build unit tasks into the build_units.yml
    puts "writing build_units.yml"
    ci = (File.exist?('build_units.yml') ? YAML.load_file('build_units.yml') : {}) || {}
    ci.delete_if {|unit, specs| unit =~ /specs/}
    partitioner.buckets.each_with_index do |bucket, i|
      ci["specs-#{i+1}"] = "rspec #{bucket.map(&:first).join(" ")}"
    end
    File.open("build_units.yml","w") do |f|
      YAML.dump(ci, f)
    end

    puts "\nPower Stride, and Ready to Ride!\nDon't forget to check in the changes"
  end

  # this task does what the description says! it randomly adds unassigned specfiles
  # to the workers.
  #
  # This is needed because the ci_assert.rb will complain otherwise
  desc "add all specs that have not been added so far to random units"
  task :quick_add do
    load 'spec/spec_helpers/ci_find_inconsistency.rb'
    if @missing_specs.empty?
      puts "all specs already included"
    else
      puts "Adding specfiles: #{@missing_specs}"

      ci = YAML.load_file('build_units.yml')

      rake_spec_units = ci.select {|unit, command| command =~ /^rspec spec/}.map(&:first)
      @missing_specs.each do |spec|
        random_unit = rake_spec_units.sort_by {|x| rand}.first
        ci[random_unit] += " #{spec}"
      end

      File.open("build_units.yml","w") do |f|
        YAML.dump(ci, f)
      end
    end
  end
end
