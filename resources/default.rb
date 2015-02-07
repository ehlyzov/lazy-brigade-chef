actions :create
default_action :create

attribute :user, kind_of: String, default: 'app'
attribute :domain, kind_of: String, name_attribute: true
attribute :environment, kind_of: String, default: 'production'
attribute :unicorn_workers, kind_of: Integer, default: 1
attribute :app_secrets, kind_of: Hash, default: {}
attribute :dotenv, kind_of: Hash, default: nil
attribute :cookbook, kind_of: String, default: nil

attr_accessor :exists
attr_reader :app_dir
attr_reader :app_name

def initialize(name, *args)
  super
  @app_name = name.split('.', 2)[0]
  @app_dir = "/srv/#{@app_name}"
end
