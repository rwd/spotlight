namespace :spotlight do
  desc 'Create an initial admin user and default exhibit'
  task initialize: :environment do
    puts 'Creating an initial admin user.'
    print 'Email: '
    email = $stdin.gets.chomp
    password = prompt_password
    u = User.create!(email: email, password: password)
    Spotlight::Role.create(user: u, exhibit: nil, role: 'admin')
    puts 'User created.'
  end

  desc 'Add application-wide admin privileges to an existing user'
  task admin: :environment do
    print 'Email: '
    email = $stdin.gets.chomp
    u = User.find_by email: email
    Spotlight::Role.create(user: u, exhibit: nil, role: 'admin')
  end

  desc 'Create a new exhibit'
  task exhibit: :environment do
    print 'Exhibit title: '
    title = $stdin.gets.chomp

    exhibit = Spotlight::Exhibit.create!(title: title)

    puts 'Who can admin this exhibit?'
    print 'Email: '
    email = $stdin.gets.chomp

    u = User.find_by(email: email)
    unless u
      puts 'User not found.'
      password = prompt_password
      u = User.create!(email: email, password: password)
    end
    Spotlight::Role.create(user: u, exhibit: exhibit, role: 'admin')
    puts 'Exhibit created.'
  end

  desc 'Import an exhibit'
  task import: :environment do
    contents = if ENV['FILE']
                 File.read(ENV['FILE'])
               else
                 STDIN.read
               end

    data = JSON.parse(contents)

    exhibit = Spotlight::Exhibit.find_or_create_by slug: data['slug'] do |e|
      e.title = data['title']
    end

    exhibit.import data

    puts Spotlight::ExhibitExportSerializer.new(exhibit).to_json
  end

  def prompt_password
    begin
      system 'stty -echo'
      print 'Password: '
      password = $stdin.gets.chomp
      puts "\n"
    ensure
      system 'stty echo'
    end
    password
  end

  namespace :check do
    desc 'Check the Solr connection and controller configuration'
    task :solr, [:model_name] => ['blacklight:check:solr', :environment] do |_, _args|
      errors = 0

      puts "[#{Blacklight.default_index.connection.uri}]"

      print ' - atomic updates:'
      begin
        id = 'test123'
        field = "test_#{Spotlight::Engine.config.solr_fields.string_suffix}"
        sample_doc = { Spotlight::Engine.blacklight_config.document_model.unique_key => id, field => { set: 'a-new-string' } }
        Blacklight.default_index.connection.add Spotlight::Engine.blacklight_config.document_model.unique_key.to_sym => id, field => 'some-string'
        Blacklight.default_index.connection.update data: [sample_doc].to_json, headers: { 'Content-Type' => 'application/json' }
        Blacklight.default_index.connection.delete_by_id id
        print " OK\n"
      rescue StandardError => e
        errors += 1
        puts e.to_s
      end

      exit 1 if errors > 0
    end
  end

  task :reindex, [:exhibit_slug] => :environment do |_, args|
    exhibits = if args[:exhibit_slug]
                 Spotlight::Exhibit.where(slug: args[:exhibit_slug])
               else
                 Spotlight::Exhibit.all
               end

    exhibits.find_each do |e|
      puts " == Reindexing #{e.title} =="
      e.reindex_later
    end
  end
end
