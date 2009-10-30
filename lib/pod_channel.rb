require 'rubygems'
require 'dm-core'
require 'dm-timestamps'
require 'pod_cast'
module Peapod
	class Channel
		include DataMapper::Resource
		# ==================== DataMapper Model Definition ==================== #
		# Manually set the table name
		storage_names[:default]='pod_channels'
		property :id, Serial, :key => true
		property :title, String
		property :description, String
		property :link, String
		property :do_sort, Boolean
		timestamps :created_at

		has n, :podcasts
		# ===================================================================== #
	end
end
