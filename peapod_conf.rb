module Peapod
class Peapod

root_dir="#{Dir.pwd}"
pod_dir = root_dir + "/poddir"

set :environment, :production
set :root, root_dir
set :podcast_dir, pod_dir
set :static, true
set :sessions, true
set :logging, true
set :run, true

configure :development do
	DataMapper.setup(
		:default, "sqlite3:///#{Dir.pwd}/devel.db")
end

configure :production do
	DataMapper.setup(
		:default, "sqlite3:///#{Dir.pwd}/prod.db")
end

if( ! File.exists? pod_dir )
	Dir.mkdir(pod_dir)
end

end
end
