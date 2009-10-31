require 'rubygems'
require 'dm-core'
require 'dm-timestamps'
require 'pod_channel'
module Peapod
	class Podcast
		include DataMapper::Resource
		# ==================== DataMapper Model Definition ==================== #
		# Manually set the table name
		storage_names[:default]='pod_casts'
		property :id, Serial, :key => true
		property :filename, String
		timestamps :created_at

		belongs_to :channel
		# ===================================================================== #
	end
end
