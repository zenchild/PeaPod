#############################################################################
# Copyright © 2009 Dan Wanek <dwanek@nd.gov>
#
#
# This file is part of Peapod.
# 
# Peapod is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# Peapod is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with Peapod.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################
$: << File.split(__FILE__).first + '/lib'
require 'rubygems'
require 'sinatra/base'
require "sinatra/authorization"
require 'rss/maker'
require 'haml'
require 'id3lib'
require 'time'
require 'dm-core'
require 'pod_channel'
require 'pod_cast'

module Peapod

class Peapod < Sinatra::Base
	attr_reader :title
	@DEBUG = false
	VERSION=1.0

	load 'peapod_conf.rb'
	
	DataMapper.auto_upgrade!

	before do
		login_required unless request.path =~ /^\/rss/
		@channels ||= Channel.all
	end

	get '/' do
		if( params[:channel] )
			haml :channel_index,
				:locals => {:channel=> Channel.get(params[:channel])}
		else
			haml :index
		end
	end

	get '/new_channel' do
		haml :new_channel
	end

	post '/new_channel' do
		title = params[:channel_name]
		descr = params[:channel_description]
		link = params[:channel_link]
		chan = Channel.new(:title => title, :description => descr, :link => link)
		chan.save
		redirect './'
	end

	get '/upload' do
		channels = Channel.all
		if( channels.length > 0 )
			haml :upload, :locals => {:channels => channels}
		else
			redirect 'new_channel'
		end
	end

	post '/upload' do
		unless params[:file] &&
			(tmpfile = params[:file][:tempfile]) &&
			(name = params[:file][:filename])
			@error = "No file selected"
			return haml(:upload)
		end
		pcast = Podcast.new
		new_file = Time.now.to_i.to_s  + "_#{name}"
		pcast.filename = new_file
		pcast.channel_id = params[:channel]
		pcast.save

		f = File.new(fpath(new_file), 'w+')
		while blk = tmpfile.read(65536)
			f.write(blk)
		end
		f.close
		haml :edit_file, :locals => {:new_file => new_file}
	end
	
	get '/edit' do
		if params[:file] == nil
			redirect './'
		end
		haml :edit_file, :locals => {:new_file => params[:file]}
	end

	post '/edit' do
		# params: presentation, presenter, summary, date
		tf = ID3Lib::Tag.new(fpath(params[:filename]))
		tf.title = params[:presentation] if params[:presentation] != nil
		tf.artist = params[:presenter] if params[:presenter] != nil
		tf.comment = params[:summary] if params[:summary] != nil
		if( params[:date] != nil )
			begin
				date = Date.parse(params[:date])
				tf.date = date.strftime('%m%d')
				tf.year = date.year
			rescue
				STDERR.puts "Invalid date specified"
			end
		end
		tf.update!
		redirect './'
	end

	get '/delete' do
		if params[:file] == nil
			redirect './'
		end
		file = fpath(params[:file])
		if( File.exists? file )
			File.unlink file
		end

		pcast = Podcast.first(:filename => params[:file])
		pcast.destroy!
		redirect './'
	end

	get '/delete_channel' do
		if params[:channel] == nil
			redirect './'
		end
		chan = Channel.get(params[:channel])
		chan.podcasts.each do |pod|
			f = fpath(pod.filename)
			if( File.exists? f )
				File.unlink f
			end
			pod.destroy!
		end
		chan.destroy!
		redirect './'
	end



	get '/download/*' do
		file = params['splat'].first
		send_file fpath(file),
			{ :filename => file }
	end

	get '/rss' do
		if( params[:channel] )
			redirect "rss2.0?channel=#{params[:channel]}"
		else
			redirect './'
		end
	end

	get '/rss2.0' do
		redirect './' unless( params[:channel] )

		chan = Channel.get(params[:channel])

		version = "2.0" # ["0.9", "1.0", "2.0"]
		content = RSS::Maker.make(version) do |m|
			m.channel.title = chan.title
			m.channel.link = chan.link
			m.channel.description = chan.description
			m.items.do_sort = true # sort items by date

			chan.podcasts.each do |pod|
				id3 = id3_from_file(pod.filename)
				date = from_id3date(id3.date, id3.year)
				date = Time.parse(date)
				i = m.items.new_item
				i.title = id3.title
				i.description = id3.comment.gsub(/\n/,'<br/>')
				link = request.url
				link = link.sub(/rss2.0.*$/,'')
				i.link = link + "download/#{pod.filename}"
				i.date = date
			end
		end
		"#{content}"
	end
	# --------- Admin Routes --------- #
	get '/cookieInfo' do
		"#{request.cookies.entries.join('<br/>&nbsp;&nbsp;&nbsp;=&gt;')}"
	end

	get '/sessionInfo' do
		"#{(session.entries).join('<br/>&nbsp;&nbsp;&nbsp;=&gt;')}"
	end
	
	get '/deleteCookies' do
		deleteCookies(request,response)
		redirect '/cookieInfo'
	end
	
	get '/deleteSession' do
		deleteSession(response)
		redirect './'
	end

	get '/migrate' do
		DataMapper.auto_migrate!
		"done"
	end


	# --------- Error Handling --------- #
	not_found do
		'Page Not Found'
	end
	
	error do
		'Sorry there was a nasty error.  Please report to the administrator. - '
			+ env['sinatra.error'].name
	end

	# --------- Helpers --------- #
	
	helpers do
		include Sinatra::Authorization
		require 'loginhash'

		def authorization_realm
			"Peapod Realm"
		end

		def authorize(login, password)
			LOGINHASH[login] == password
		end

		def partial(template, *args)
			options = args.last.is_a?(Hash) ? args.last : {}
			options.merge!(:layout => false)
			if collection = options.delete(:collection) then
				collection.inject([]) do |buffer, member|
					buffer << haml(template, options.merge(
						:layout => false,
						:locals => {template.to_sym => member}))
				end.join("\n")
			else
				haml(template, options)
			end
		end
		
		def from_id3date(date, year)
			datestr = ''
			if date != nil and year != nil
				if date =~ /^..\/..\/....$/
					datestr = date
				elsif date =~ /^....$/
					datestr = date.sub /^(..)(..)/, '\1/\2/'
					datestr += year
				else
					datestr = ''
				end
			end
			return datestr
		end

		def id3_from_file(filename)
			return ID3Lib::Tag.new(fpath(filename))
		end

		def fpath(fname)
			return "#{options.podcast_dir}/#{fname}"
		end
	end  # end helpers
	
	def deleteCookie(response,key,value)
		response.set_cookie(key, {
			:expires => (Time.new - 86400),
			:value => value})
	end
	
	def deleteCookies(req,resp)
		req.cookies.keys.each do |key|
			deleteCookie(resp,key,req.cookies[key])
		end
	end
	
	def deleteSession(response)
		@env['rack.session.options'][:expire_after] = 0
	end

end
end
